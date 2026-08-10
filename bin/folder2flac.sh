#!/bin/bash
#made by githubuser addei
#GPL 2.0

# empty globs expand to nothing instead of the literal pattern
shopt -s nullglob

usage() {
	cat <<'EOF'
folder2flac.sh - convert existing WAV rips to tagged FLAC, in place

Usage:
  folder2flac.sh [-h|--help] [ROOT]

Description:
  Walks ROOT (default: current directory) looking for folders laid out as
  Artist/Album that contain .wav files (e.g. trackNN.cdda.wav), encodes every
  WAV to FLAC, verifies the encode is lossless, tags each track from
  MusicBrainz, and renames the files to "NN Title.flac". Your folder layout is
  left untouched - only the audio files inside each album folder change.

What it does, per album folder:
  1. Encodes each *.wav to FLAC with ffmpeg.
  2. Verifies each FLAC decodes to the same audio as its WAV (decoded-audio MD5);
     on a match the WAV is removed, otherwise both are kept and it is flagged.
  3. Looks the album up on MusicBrainz: resolves the artist name to an id first
     (so romanized names still match non-Latin artists), then finds the release
     whose track count matches this folder.
  4. Writes ARTIST/ALBUM/DATE/TRACKNUMBER/TRACKTOTAL/TITLE tags with metaflac and
     renames the files to "NN Title.flac". With no match, tags come from the
     Artist/Album folder names and files stay numbered.

Options:
  -h, --help    Show this help and exit.

Requirements:
  Required:            ffmpeg, metaflac
  Metadata (optional): curl, jq
EOF
}

case "${1:-}" in
	-h|--help) usage; exit 0 ;;
esac

root="${1:-.}"
if [ ! -d "$root" ]; then
	echo "Not a directory: $root" >&2
	exit 2
fi

# ffmpeg encodes, metaflac tags; both are mandatory
missing=0
for tool in ffmpeg metaflac; do
	command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; missing=1; }
done
[ "$missing" -ne 0 ] && { echo "Please install the missing tools before running this script." >&2; exit 1; }

# metadata lookup is best-effort; disable it if curl or jq is absent
metadata=1
for tool in curl jq; do
	command -v "$tool" >/dev/null 2>&1 || metadata=0
done
[ "$metadata" -eq 0 ] && echo "note: curl/jq not found, tagging from folder names only"

UA="folder2flac/1.0 ( https://github.com/addei/scripts )"

# percent-encode a string for a URL query (jq is already a metadata dependency)
enc() { jq -rn --arg s "$1" '$s|@uri'; }

# GET a MusicBrainz URL, staying under its 1 request/second courtesy limit
mb() { sleep 1; curl -s -A "$UA" "$1"; }

# resolve "Artist" + "Album" + track count to a chosen release id, echoed on stdout
find_release() {
	local artist="$1" album="$2" n="$3" arid rel
	arid=$(mb "https://musicbrainz.org/ws/2/artist/?query=$(enc "$artist")&fmt=json&limit=1" \
		| jq -r '.artists[0].id // empty' 2>/dev/null)
	if [ -n "$arid" ]; then
		rel=$(mb "https://musicbrainz.org/ws/2/release/?query=$(enc "arid:$arid AND release:$album")&fmt=json&limit=25")
	else
		rel=$(mb "https://musicbrainz.org/ws/2/release/?query=$(enc "artist:$artist AND release:$album")&fmt=json&limit=25")
	fi
	# prefer the release whose track count matches this folder, else the top hit
	printf '%s' "$rel" | jq -r --argjson n "$n" \
		'first(.releases[] | select(([.media[]?."track-count"]|add)==$n) | .id) // (.releases[0]?.id // empty)' 2>/dev/null
}

# encode + verify + tag + rename every WAV in one album folder
process_album() {
	local dir="$1"
	local artist album n i f flac bytes wavmd5 flacmd5
	local mbid data mb_artist mb_album date year title num total dest
	local -a titles args

	artist=$(basename "$(dirname "$dir")")
	album=$(basename "$dir")
	echo "== $artist / $album =="

	# encode each WAV to FLAC and confirm the encode is bit-for-bit lossless
	for f in "$dir"/*.wav "$dir"/*.WAV; do
		[ -e "$f" ] || continue
		flac="${f%.*}.flac"
		ffmpeg -v error -y -i "$f" -c:a flac "$flac" </dev/null
		wavmd5=$(ffmpeg -v error -i "$f" -map 0:a -f md5 - </dev/null)
		flacmd5=$(ffmpeg -v error -i "$flac" -map 0:a -f md5 - </dev/null)
		if [ -n "$wavmd5" ] && [ "$wavmd5" = "$flacmd5" ]; then
			rm -f "$f"
		else
			echo "  LOSSY/FAILED encode, keeping WAV: $(basename "$f")"
		fi
	done

	# count the FLACs we now have; nothing to do if the folder had no audio
	n=0; for f in "$dir"/*.flac; do n=$((n+1)); done
	[ "$n" -eq 0 ] && { echo "  no audio in this folder"; return; }

	# look up track titles, canonical artist/album and date from MusicBrainz
	mb_artist=""; mb_album=""; date=""
	if [ "$metadata" -eq 1 ]; then
		mbid=$(find_release "$artist" "$album" "$n")
		if [ -n "$mbid" ]; then
			data=$(mb "https://musicbrainz.org/ws/2/release/$mbid?inc=recordings+artist-credits&fmt=json")
			mb_artist=$(printf '%s' "$data" | jq -r '."artist-credit"[0].name // empty' 2>/dev/null)
			mb_album=$(printf '%s'  "$data" | jq -r '.title // empty' 2>/dev/null)
			date=$(printf '%s'      "$data" | jq -r '.date // empty' 2>/dev/null)
			# titles from the medium matching this folder (NUL-separated for safe spaces)
			while IFS= read -r -d '' title; do titles+=("$title"); done < <(
				printf '%s' "$data" | jq -j --argjson n "$n" \
					'(([.media[] | select((.tracks|length)==$n)][0]) // .media[0]).tracks[] | .title + "\u0000"' 2>/dev/null)
		fi
	fi

	# fall back to the folder names when MusicBrainz has nothing
	[ -n "$mb_artist" ] || mb_artist="$artist"
	[ -n "$mb_album" ]  || mb_album="$album"
	year=${date%%-*}
	total=${#titles[@]}
	if [ "$total" -gt 0 ]; then
		echo "  matched '$mb_artist - $mb_album' (${total} tracks)"
	else
		echo "  no MusicBrainz match, tagging from folder names"
	fi

	# tag and rename each FLAC in sorted (track) order
	i=0
	for f in "$dir"/*.flac; do
		i=$((i+1))
		title=${titles[$((i-1))]:-}
		args=(--remove-tag=ARTIST --remove-tag=ALBUMARTIST --remove-tag=ALBUM
		      --remove-tag=TITLE --remove-tag=TRACKNUMBER --remove-tag=TRACKTOTAL --remove-tag=DATE
		      --set-tag="ARTIST=$mb_artist" --set-tag="ALBUMARTIST=$mb_artist" --set-tag="ALBUM=$mb_album"
		      --set-tag="TRACKNUMBER=$i")
		[ "$total" -gt 0 ] && args+=(--set-tag="TRACKTOTAL=$total")
		[ -n "$year" ]     && args+=(--set-tag="DATE=$year")
		[ -n "$title" ]    && args+=(--set-tag="TITLE=$title")
		metaflac "${args[@]}" "$f"

		num=$(printf '%02d' "$i")
		if [ -n "$title" ]; then
			mv -f "$f" "$dir/$num ${title//\//-}.flac"
		fi
	done
}

# every folder that directly contains WAV files is treated as one album
found=0
while IFS= read -r dir; do
	[ -n "$dir" ] || continue
	found=1
	process_album "$dir"
done < <(find "$root" -type f \( -name '*.wav' -o -name '*.WAV' \) -exec dirname {} \; | sort -u)

[ "$found" -eq 0 ] && { echo "No .wav files found under: $root"; exit 0; }
echo "Done."
