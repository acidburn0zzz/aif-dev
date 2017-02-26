#!/usr/bin/bash

fns=($(awk -F'=' '/^_/ {print $1}' "../data/translations/english.trans"))

for lg in ../data/translations/*.trans ; do
    not=$(grep -cE "#.*translate me" "${lg}")
    echo -e "\n-- $(basename "${lg}") ${not} to translate --"
    for key in "${fns[@]}"; do
        if (( $(grep -oEc "^${key}=" "${lg}") != 1)); then
            echo -e "\t${key} not exist"
        fi
    done
done

#echo -e "${fns[*]}"