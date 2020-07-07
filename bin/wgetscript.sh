#!/bin/sh
#automated file downloading script

#made by githubuser addei
#GPL 2.0

#variables and path(s)
declare -a dependencies=("wget" "cat" "grep")
declare -a links
sleeptimer=3
destination="#*PATH TO THE DESTINATION DIRECTORY*#"
swgetsettings="--directory-prefix=$destination --tries 3 --rejected-log=$destination/r.log --show-progress "
listoflinkspath="#*PATH TO THE LIST OF URLS*#" #urls must be listed on its own lines

#functions
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

createInstFolder() { #this function checks if the folder exists
    if [ ! -d "$destination" ] ; then
        echo "Destination directory does not exists"
        mkdir $destination
        echo "Directory created!"
    else
        echo "Directory exists already!"
    fi
}

getList() { #takes urls from the given list
    links=($(cat $listoflinkspath $1))
    echo "There are "${#links[@]}" link(s) in the list!"
}

getFiles() { #downloads files using list
    for i in "${links[@]}"
    do
        wget $swgetsettings $i
        sleep $sleeptimer
    done
    
}

#main
checkDependencies
createInstFolder
getList
getFiles
echo "DONE!"
exit 0
