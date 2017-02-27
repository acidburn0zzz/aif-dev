#!/usr/bin/bash

fns=($(awk -F'=' '/^_/ {print $1}' "../data/translations/english.trans"))

for lg in ../data/translations/*.trans ; do
    trans=$(<"${lg}")
    not=$(echo "${trans}" | grep -cE "#.*translate me")
    echo -e "\n-- $(basename "${lg}") ${not} to translate --"
    for key in "${fns[@]}"; do
        if [[ ! $trans =~ $key ]]; then
            echo -e "\t${key} not exist"
        fi
    done
done

#echo -e "${fns[*]}"