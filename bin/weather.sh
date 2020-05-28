#!/bin/sh
#really small script for checking weather from terminal using wttr.in backend by igor_chubin

#alias setup when script is in ~/bin
#export PATH="${PATH}:${HOME}/bin"
#alias weather='f(){sh weather.sh $1}; f'

#made by githubuser addei
#GPL 2.0

declare -a dependencies=("curl")
city=$1

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

getWeather() {
    curl wttr.in/$city
}

checkDependencies
getWeather
exit
