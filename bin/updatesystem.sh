#!/bin/bash
#script for updating system
#made by githubuser addei
#GPL 2.0

declare -a dependencies=("type" "sudo" "cat")
declare -a pkgmanagers=("apt" "zypper" "tumbleweed")
declare -l pkgmanager


checkDependencies() { #this function checks if the required dependencies are found 
    declare -i flag=0
    for i in "${dependencies[@]}"
    do
        if ! type "$i" > /dev/null ; then
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

checkforsudo() {
    if ! sudo cat /dev/null ; then
    echo "unable to obtain sudo"
    exit 1
    fi
}

checkPKGmanager() { # this function checks for supported package managers
    declare -i flag=1
    for i in "${pkgmanagers[@]}"
    do
        if type "$i" >/dev/null ; then
            flag=0
            pkgmanager=$i
        fi
    done
    echo "$pkgmanager found!"
    if [ ! $flag -eq 0 ] ; then
        echo "You need to have one of the following package manager installed: ${pkgmanagers[*]}"
        exit 1
    fi
}

updateSystem() {
    if [ "$pkgmanager" == "apt" ] ; then
        sudo apt update
        sudo apt upgrade -y
    fi

    if [ "$pkgmanager" == "zypper" ] ; then
        sudo zypper update -y
    fi

    if [ "$pkgmanager" == "tumbleweed" ] ; then
        sudo tumbleweed update
    fi
 
}

set -e
checkDependencies
checkforsudo
checkPKGmanager
updateSystem
exit
