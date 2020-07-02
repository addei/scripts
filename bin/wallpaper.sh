#!/bin/sh
#made by githubuser addei
#GPL 2.0

#Variables and path(s)

declare -a dependencies=("sway" "swaybg" "grep" )
declare -a outputdevices
declare -a bgfiles
folderpath="*path to your wallpaper folder*"
timer=5m #timer, default in seconds, m in minutes and h in hours.
displayCount=$(swaymsg -p -t get_outputs | grep -c 'Output') #display count
bgid="$(pgrep swaybg)"

#functions

checkifRunning(){
    if pidof -x "wallpaper.sh" >/dev/null; then
        echo "Process already running"
        exit 1
    fi
}

checkDependencies() { #this function checks if the required dependencies are found 
    declare -i flag=0
    for i in "${dependencies[@]}"
    do
        if ! type $i >/dev/null ; then
            if [ $flag -eq 0 ] ; then
                flag=1
            fi
            echo "$i is missing"
        fi
    done
    if [ ! $flag -eq 0 ] ; then
        echo "You need to have following dependencies installed: ${dependencies[*]}"
        exit 1
    fi
}

checkOutputdevices() { #checks output devices
    if [ $displayCount -gt 0 ] ; then
        outputdevices=($(swaymsg -p -t get_outputs | grep 'Output' | grep -oP '(?<=Output )[^ ]*' $1))
    
    else
        exit 1
    fi
}

checkFoldercontent() {
    bgfiles=($(ls -x $folderpath $1))
}

setbgonOutputdevices () {    
    PAR=""
    for i in "${outputdevices[@]}"
    do
        PAR+=" -o $i -i $folderpath/${bgfiles[RANDOM%${#bgfiles[@]}]} -m fill"
    done
    swaybg$PAR &
}

#main

checkifRunning
checkDependencies
checkOutputdevices
checkFoldercontent

while :
do
    if pidof -x "swaybg" >/dev/null; then
        killall swaybg
    fi
    setbgonOutputdevices
    sleep $timer
done

exit 0
