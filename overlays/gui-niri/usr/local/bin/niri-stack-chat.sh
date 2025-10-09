#!/bin/bash

function windows {
    niri msg --json windows
}

function in_windows {
    windows | jq -e '.[] | select(.app_id == "'"$1"'")' >/dev/null 2>&1
}

function chat_open {
    in_windows discord && in_windows im.riot.Riot
}

function id {
    windows | jq -r '.[] | select(.app_id == "'"$1"'") | .id'
}

function position {
    windows | jq -r '.[] | select(.app_id == "'"$1"'") | .layout.pos_in_scrolling_layout | first'
}

function rightmost {
    max_position_app=''
    max_position='0'
    for app in "${@}"; do
        pos=$(position $app)
        if (( pos > max_position )); then
            max_position_app=$app
            max_position=$pos
        fi
    done
    id $max_position_app
}

while ! chat_open; do
    sleep 1
done

niri msg action consume-or-expel-window-left --id=$(rightmost im.riot.Riot discord)
