#!/bin/bash
#made by githubuser addei
#GPL 2.0

#Dependencies: sway, swaylock, grim, imagemagicks, grep, rm, Lato (font)
declare -a dependencies=("sway" "swaylock" "grim" "convert" "grep" "rm")
declare -a outputdevices
#Variables and path(s)
imagename="lockshot"
imagepath="/tmp"
displayCount=$(swaymsg -p -t get_outputs | grep -c 'Output')
swaylocksettings="-f -e -F --font Lato --font-size 12"

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

makeBackground() { #makes background for the output devices
    for i in "${outputdevices[@]}"
    do
        grim -o $i $imagepath/$imagename$i.png &
    done
    wait

    for i in "${outputdevices[@]}"
    do
        convert $imagepath/$imagename$i.png -filter Gaussian -blur 50x20 $imagepath/$imagename$i.png &
    done
    wait
}

lockDevice() { #assigns backgrounds for the locking software and locks the device
    PAR=""
    for i in "${outputdevices[@]}"
    do
        PAR+="-i $i:$imagepath/$imagename$i.png "
    done

    swaylock $swaylocksettings $PAR

    for i in "${outputdevices[@]}"
    do
        rm $imagepath/$imagename$i.png
    done
}

checkDependencies
checkOutputdevices
makeBackground
lockDevice
exit 0
