#!/bin/bash
#script for updating list of GNU/Linux systems by using updatesystem.sh script
#made by githubuser addei
#GPL 2.0

declare -a listofhostnamesipandports
hostparameters="/home/$USER/.hostparameters" #make a txt file in in this path. Syntax (per line) username@address -p portnmb
readarray -t listofhostnamesipandports < "$hostparameters"


for i in "${listofhostnamesipandports[@]}"
do
    echo "$i"
    ssh -t $i ./updatesystem.sh
done
