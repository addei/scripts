#!/bin/sh
#made by githubuser addei
#GPL 2.0

version="2.1.0"
appImage="RuneLite.AppImage"
jarImage="RuneLite.jar"
appurl="https://github.com/runelite/launcher/releases/download/$version/$appImage"
jarurl="https://github.com/runelite/launcher/releases/download/$version/$jarImage"
jar="JAR"
appimage="APPIMAGE"
destination="/home/$USER/.runelite"
declare -a dependencies=("curl" "grep" "java" "whiptail")

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

launchGame() {
    if [ -f "$destination/$appImage" ] ; then
        exec "$destination/$appImage" &
    elif [ -f "$destination/$jarImage" ] ; then
        java -jar "$destination/$jarImage" &
    else
        echo "The gamefile is missing, do you want download it and install it now?"
        installGame
    fi
}

installGame() {
    if (whiptail --title "RuneLite installation wizard" --yesno "The gamefile is missing, do you want download it and install it now?" 8 80)
    then
        echo "Yes, the exit status was $?."
        createInstFolder
        downloadGame
    else
        exit $?
    fi
}

createInstFolder() { #this function checks if the folder for the installation is present and if not it creates it
    if [ ! -d "$destination" ] ; then
        echo "Installation folder does not exists"
        whiptail \
            --title "RuneLite installation wizard" \
            --msgbox "Installation folder does not exists, creating it now." 8 78
        mkdir $destination
    else
        echo "Installation folder exists already."
        whiptail \
            --title "runelite.sh | RuneLite installation wizard" \
            --msgbox "Installation folder exists already." 8 78
    fi
}

downloadGame() {
    ANS=$(whiptail --title "RuneLite installation wizard" --menu \
    "Which version you want to install?" 15 60 4 \
    "$appimage" "Install AppImage." \
    "$jar" "Install JAR version." 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [[ "$ANS" == "$jar" ]]; then
            echo "User selected $jar."
            curl -SLO "$jarurl"
            mv "$jarImage" "$destination"
            whiptail \
            --title "RuneLite installation wizard" \
            --msgbox "You need to change file permission manually." 8 78
            echo "You need to change file permission manually."
            echo "Example:"
            echo "# chmod -R 744 "$destination"/"$jarImage""
        elif [[ "$ANS" == "$appimage" ]]; then
            echo "User selected $appimage."
            curl -SLO "$appurl"
            mv "$appImage" "$destination"
            whiptail \
            --title "RuneLite installation wizard" \
            --msgbox "You need to change file permission manually." 8 78
            echo ""
            echo "You need to change file permission manually."
            echo "Example:"
            echo "# chmod -R 744 "$destination"/"$appImage""
        fi
    else
        echo "You chose Cancel."
        exit $exitstatus
    fi
}

set -e
checkDependencies
launchGame
exit
