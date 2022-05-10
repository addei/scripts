#!/bin/bash
#delete all wireguard connections using nmcli
#version 0.1 alpha
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"
declare -a connections
connections=($(nmcli connection show | grep "wireguard" | awk '{print $1;}'))
echo ""${#connections[@]}" connection(s) found!"
echo "Removing all the Wireguard connections in 5 seconds"
sleep 5
for i in "${connections[@]}"
do
    nmcli connection delete $i
done
