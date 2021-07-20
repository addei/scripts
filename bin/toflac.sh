#!/bin/bash
#made by githubuser addei
#GPL 2.0

#declare success variable
declare -i success=0

# analyse cd content
cdparanoia -vsQ |& tee -a cd_content.log

# retrieves audio tracks
cdparanoia -Bl
for f in *.wav; do sox "$f" "${f%%.wav}.flac" --multi-threaded; done
sleep 2

# test quality of the wav -> flac conversion
for f in *.wav; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> wavhash.txt; done
for f in *.flac; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> flachash.txt; done

# compare hashes
cmp --silent wavhash.txt flachash.txt || success=1

# remove .wav and .txt files if hashes match
[ $success -eq 0 ] && for f in *.wav; do rm "$f"; done || echo "files are different" > FILESAREDIFFERENT.txt
[ $success -eq 0 ] && for f in *.txt; do rm "$f"; done || echo "check out hash content"

# echo
[ $success -eq 0 ] && echo "All good, ejecting CD now!" || echo "Some errors occured, ejecting CD now!"

# eject the disc from the drive
eject -T

# start ID3 Tagger
[ $success -eq 0 ] && kid3 dir "&(pwd)" & disown kid3 || echo "..."
