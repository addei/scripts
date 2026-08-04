#!/bin/bash
#made by githubuser addei
#GPL 2.0

# empty globs expand to nothing instead of the literal pattern
shopt -s nullglob

#declare success variable
declare -i success=0

usage() {
	cat <<'EOF'
toflac.sh - rip an audio CD to verified, tagged FLAC

Usage:
  toflac.sh [-h|--help]

Description:
  Rips the inserted audio CD, encodes each track to FLAC, checks the
  conversion is lossless, then tags and files the tracks automatically.
  Run it from the folder where the Artist/Album tree should be created,
  with an audio CD in the drive. It takes no positional arguments.

What it does:
  1. Logs the disc table of contents to cd_content.log (cdparanoia -Q).
  2. Rips every track to WAV and encodes to FLAC with sox.
  3. Verifies each FLAC decodes to the same audio as its WAV (ffmpeg hash + cmp).
  4. On a match, removes the WAV/temp files; otherwise keeps them and flags it.
  5. Identifies the disc on MusicBrainz by its TOC, writes tags with metaflac,
     renames files to "NN Title.flac" and files them as Artist/Album/
     (a multi-disc set is split into Artist/Album/CD1, CD2, ...).
  6. Ejects the disc. If MusicBrainz has no match, opens kid3 for manual tagging.

Options:
  -h, --help    Show this help and exit.

Requirements:
  Required:            cd-paranoia (macOS) / cdparanoia (Linux), sox, ffmpeg, cmp
  Metadata (optional): cd-discid, curl, jq, metaflac, openssl
  Manual fallback:     kid3 GUI (macOS: kid3.app, Linux: kid3)
EOF
}

# handle command-line options
case "${1:-}" in
	-h|--help) usage; exit 0 ;;
	"") ;;
	*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

# detect OS and pick platform-specific commands
case "$(uname -s)" in
	Darwin)
		cdparanoia_cmd="cd-paranoia"
		eject_cmd=(drutil tray eject)
		cd_device=""
		gui_cmd=(); [ -d /Applications/kid3.app ] && gui_cmd=(open -a kid3)
		gui_background=""
		;;
	*)
		cdparanoia_cmd="cdparanoia"
		eject_cmd=(eject -T)
		cd_device="/dev/cdrom"
		gui_cmd=(); command -v kid3 >/dev/null 2>&1 && gui_cmd=(kid3)
		gui_background=1
		;;
esac

# check that all required tools are installed
missing=0
for tool in "$cdparanoia_cmd" sox ffmpeg cmp; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "Missing required tool: $tool" >&2
		missing=1
	fi
done
if [ "$missing" -ne 0 ]; then
	echo "Please install the missing tools before running this script." >&2
	exit 1
fi

# identify disc via MusicBrainz TOC, tag with metaflac, rename + folder with kid3 (best-effort)
lookup_metadata() {
	local tool toc json pick artist album date disc discs year n i title total f
	local dest safe_artist safe_album safe_title num
	local -a titles args
	for tool in cd-discid curl jq metaflac; do
		command -v "$tool" >/dev/null 2>&1 || { echo "metadata: $tool not found, skipping auto-tag"; return 1; }
	done

	# find the optical device; on macOS cd-discid needs the raw device (/dev/rdiskN)
	local dev raw nf last leadout offs
	if [ "$(uname -s)" = "Darwin" ]; then
		dev=$(drutil status 2>/dev/null | grep -o '/dev/disk[0-9][0-9]*' | head -1)
		[ -n "$dev" ] && dev=${dev/disk/rdisk}
	else
		dev="$cd_device"
	fi

	if [ -n "$dev" ]; then
		raw=$(cd-discid --musicbrainz "$dev" 2>/dev/null)
	else
		raw=$(cd-discid --musicbrainz 2>/dev/null)
	fi
	[ -z "$raw" ] && { echo "metadata: could not read disc TOC"; return 1; }

	# cd-discid prints "lasttrack off1..offN leadout"; MusicBrainz wants
	# "firsttrack lasttrack leadout off1..offN", so reorder the fields
	local -a fields
	read -r -a fields <<< "$raw"
	nf=${#fields[@]}
	[ "$nf" -lt 3 ] && { echo "metadata: could not read disc TOC"; return 1; }
	last=${fields[0]}
	leadout=${fields[$((nf-1))]}
	offs="${fields[@]:1:nf-2}"
	toc="1 $last $leadout $offs"

	# how many tracks we ripped (used for matching and as a fallback key)
	n=0; for f in *.flac; do n=$((n+1)); done

	# exact match first: compute the MusicBrainz disc id (libdiscid algorithm), which
	# resolves the correct disc even when discs in a set share the same track count
	pick=""
	if command -v openssl >/dev/null 2>&1; then
		local discid discid_str o
		local -a off_arr
		discid_str=$(printf '%02X%02X' 1 "$last")
		discid_str+=$(printf '%08X' "$leadout")
		off_arr=($offs)
		i=0; while [ $i -lt 99 ]; do o=${off_arr[$i]:-0}; discid_str+=$(printf '%08X' "$o"); i=$((i+1)); done
		discid=$(printf '%s' "$discid_str" | openssl dgst -sha1 -binary | openssl base64 -A | tr '+/=' '._-')
		json=$(curl -s -A "toflac/1.0 ( https://github.com/addei/scripts )" \
			"https://musicbrainz.org/ws/2/discid/$discid?inc=recordings+artists&fmt=json")
		pick=$(printf '%s' "$json" | jq -c --arg id "$discid" '
			first(.releases[]? | . as $r | $r.media[]
				| select(any(.discs[]?; .id == $id))
				| {artist:($r."artist-credit"[0].name), album:$r.title, date:($r.date // ""),
				   disc:(.position // 1), discs:(($r.media)|length), tracks:[(.tracks // [])[].title]})
		' 2>/dev/null)
	fi

	# fall back to a fuzzy TOC lookup when the disc has no id match in MusicBrainz
	if [ -z "$(printf '%s' "$pick" | jq -r '.album // empty' 2>/dev/null)" ]; then
		json=$(curl -s -A "toflac/1.0 ( https://github.com/addei/scripts )" \
			"https://musicbrainz.org/ws/2/discid/-?toc=${toc// /+}&inc=recordings+artists&fmt=json")
		pick=$(printf '%s' "$json" | jq -c --argjson n "$n" '
			first(.releases[] | . as $r | $r.media[]
				| select(((.tracks // [])|length) == $n)
				| {artist:($r."artist-credit"[0].name), album:$r.title, date:($r.date // ""),
				   disc:(.position // 1), discs:(($r.media)|length), tracks:[(.tracks // [])[].title]})
			// (.releases[0] // {} | {artist:(."artist-credit"[0].name), album:.title, date:(.date // ""),
				   disc:1, discs:1, tracks:[((.media[0].tracks) // [])[].title]})
		' 2>/dev/null)
	fi

	artist=$(printf '%s' "$pick" | jq -r '.artist // empty' 2>/dev/null)
	album=$(printf '%s'  "$pick" | jq -r '.album  // empty' 2>/dev/null)
	date=$(printf '%s'   "$pick" | jq -r '.date   // empty' 2>/dev/null)
	disc=$(printf '%s'   "$pick" | jq -r '.disc   // 1' 2>/dev/null)
	discs=$(printf '%s'  "$pick" | jq -r '.discs  // 1' 2>/dev/null)

	if [ -z "$artist" ] || [ -z "$album" ]; then
		echo "metadata: no MusicBrainz match, leaving tags for manual tagging in kid3"
		return 1
	fi
	echo "metadata: detected '$artist - $album'"
	while IFS= read -r -d '' title; do titles+=("$title"); done \
		< <(printf '%s' "$pick" | jq -j '.tracks[] | . + "\u0000"' 2>/dev/null)

	year=${date%%-*}
	total=${#titles[@]}

	# destination folder from tags; '/' is illegal in a path component.
	# a multi-disc set gets a per-disc subfolder (CD1, CD2, ...)
	safe_artist=${artist//\//-}
	safe_album=${album//\//-}
	dest="$safe_artist/$safe_album"
	[ "${discs:-1}" -gt 1 ] && dest="$dest/CD$disc"
	mkdir -p "$dest"

	# write tags per track (metaflac avoids shell-quoting issues); file order matches
	# track order. Only the freshly-ripped top-level *.flac are touched, so any
	# pre-existing album folders in the current directory are left untouched.
	i=0
	for f in *.flac; do
		i=$((i+1))
		title=${titles[$((i-1))]:-}
		args=(--remove-tag=ARTIST --remove-tag=ALBUMARTIST --remove-tag=ALBUM
		      --remove-tag=TITLE --remove-tag=TRACKNUMBER --remove-tag=TRACKTOTAL --remove-tag=DATE
		      --remove-tag=DISCNUMBER --remove-tag=DISCTOTAL
		      --set-tag="ARTIST=$artist" --set-tag="ALBUMARTIST=$artist" --set-tag="ALBUM=$album"
		      --set-tag="TRACKNUMBER=$i" --set-tag="DISCNUMBER=$disc" --set-tag="DISCTOTAL=$discs")
		[ "$total" -gt 0 ] && args+=(--set-tag="TRACKTOTAL=$total")
		[ -n "$year" ]      && args+=(--set-tag="DATE=$year")
		[ -n "$title" ]     && args+=(--set-tag="TITLE=$title")
		metaflac "${args[@]}" "$f"

		# rename to "NN Title.flac" and file under Artist/Album
		num=$(printf '%02d' "$i")
		if [ -n "$title" ]; then
			safe_title=${title//\//-}
			mv "$f" "$dest/$num $safe_title.flac"
		else
			mv "$f" "$dest/$num.flac"
		fi
	done
}

# analyse cd content
"$cdparanoia_cmd" -Q 2>&1 | tee -a cd_content.log

# retrieves audio tracks
"$cdparanoia_cmd" -B
# drop the pre-gap before track 1 (batch mode writes it as track00, no audio)
rm -f track00.cdda.wav
for f in *.wav; do sox "$f" "${f%%.wav}.flac" --multi-threaded; done
sleep 2

# a real CD track is always far larger than 1 KB, and the TOC has no track 0,
# so any file this small is a bogus artifact (empty read / pre-gap) - drop it
for f in *.wav *.flac; do
	bytes=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
	if [ -z "$bytes" ] || [ "$bytes" -lt 1000 ]; then
		echo "skipping bogus file '$f' ($bytes bytes)"
		rm -f "$f"
	fi
done

# test quality of the wav -> flac conversion
for f in *.wav; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> wavhash.txt; done
for f in *.flac; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> flachash.txt; done

# compare hashes
cmp --silent wavhash.txt flachash.txt || success=1

# remove .wav and .txt files if hashes match
tagged=1
if [ $success -eq 0 ]; then
	for f in *.wav; do rm "$f"; done
	for f in *.txt; do rm "$f"; done
	# tag while the disc is still in the drive (TOC lookup needs it)
	lookup_metadata && tagged=0
	echo "All good, ejecting CD now!"
else
	echo "files are different" > FILESAREDIFFERENT.txt
	echo "check out hash content"
	echo "Some errors occured, ejecting CD now!"
fi

# eject the disc from the drive
"${eject_cmd[@]}"

# open kid3 for manual tagging only if auto-tagging did not succeed
if [ $success -eq 0 ] && [ "$tagged" -ne 0 ]; then
	if [ "${#gui_cmd[@]}" -eq 0 ]; then
		echo "kid3 GUI not available; tag the files in $(pwd) manually"
	elif [ -n "$gui_background" ]; then
		"${gui_cmd[@]}" "$(pwd)" & disown
	else
		"${gui_cmd[@]}" "$(pwd)"
	fi
fi
