#!/bin/bash

set -e

notify() {
    msg="${1}"
    shift
    notify-send "${@}" "Neversink Update" "$msg"
}

webclean() {
    sed -e 's/ /%20/g'
}

find_filter_dir() {
    local possible_bases=(
        "$HOME/.steam/steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        /mnt/*/steam/Steam
    )
    local possible_user_folders=(
        users
        Users
    )
    for base in "${possible_bases[@]}"; do
        for user_folder in "${possible_user_folders[@]}"; do
            local possible_filter_dir="${base}/steamapps/compatdata/2694490/pfx/drive_c/${user_folder}/steamuser/My Documents/My Games/Path of Exile 2"
            if [ -d "$possible_filter_dir" ]; then
                echo "$possible_filter_dir"
                return 0
            fi
        done
    done
    local err="Unable to find a directory to place the filters in. Have you launched PoE2 in Steam yet?"
    echo "$err" >&2
    notify "$err" -u critical
    echo /directory-not-found
}
cd "$(find_filter_dir)"

declare -A modes
# modes['/']=''
modes['/(STYLE) DARKMODE/']=' (darkmode) '
versions=(
#    0-SOFT
#    1-REGULAR
    2-SEMI-STRICT
    3-STRICT
    4-VERY-STRICT
#    5-UBER-STRICT
#    6-UBER-PLUS-STRICT
)

url_base="https://raw.githubusercontent.com/NeverSinkDev/NeverSink-Filter-for-PoE2/refs/heads/main"

for ver in "${versions[@]}"; do
    for modefolder in "${!modes[@]}"; do
        mode="${modes[$modefolder]}"
        filename="NeverSink's filter 2 - $ver$mode.filter"
        web_filename="$(echo "$modefolder" | webclean)$(echo "$filename" | webclean)"
        url="${url_base}${web_filename}"
        echo "$filename"
        if curl -sSLo "$filename" -z "$filename" "$url"; then
            notify "Downloaded $filename" -e -t 1500
        else
            notify "Failed to download $filename" -u critical
        fi
    done
done
