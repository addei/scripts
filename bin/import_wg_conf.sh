#!/bin/bash
#not so efficient way to import wireguard configuration files from a folder
#version 0.1 alpha

declare -a configs
configs=($(find -maxdepth 1 -name "*.conf"))
echo ""${#configs[@]}" configuration file(s) found!"

for i in "${configs[@]}"
do
    sudo nmcli connection import type wireguard file $i
    nmcli device disconnect $(echo $i | sed 's/^..//' | cut -d "." -f 1)
done
