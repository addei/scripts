#!/bin/bash
cdparanoia -vsQ
sleep 5
cdparanoia -Bl
sleep 5

mkdir converted
for f in *.wav; do sox "$f" "converted/${f%%.wav}.flac" --multi-threaded; done 
sleep 5

# test quality of the wav -> to flac conversion
for f in *.wav; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> wavhash.txt; done
for f in converted/*.flac; do ffmpeg -loglevel error -i "$f" -map 0 -f hash - >> converted/flachash.txt; done

# compare hashes
cmp --silent wavhash.txt converted/flachash.txt || echo "files are different" > FILESAREDIFFERENT.txt

eject -T
