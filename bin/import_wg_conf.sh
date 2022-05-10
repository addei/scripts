#!/bin/bash
#not so efficient way to import wireguard configuration files from a folder
#version 0.2 alpha
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"
declare -a configs
counter=1
configs=($(ls | grep ".conf"))
echo ""${#configs[@]}" configuration file(s) found!"

for i in "${configs[@]}"
do
    echo ""$counter"/"${configs[@]}" - "$i""
    nmcli connection import type wireguard file $i
    nmcli device disconnect $(echo $i | cut -d "." -f 1)
    nmcli connection modify $(echo $i | cut -d "." -f 1) connection.autoconnect no
    nmcli connection modify $(echo $i | cut -d "." -f 1) ipv4.dhcp-send-hostname no
    nmcli connection modify $(echo $i | cut -d "." -f 1) ipv6.dhcp-send-hostname no
    ((counter++))
done
