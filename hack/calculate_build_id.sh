#!/bin/bash -e
image="$1"
build_date="$2"
skopeo inspect "docker://$image" | \
    jq -r '
        .Labels."org.opencontainers.image.version"
            | split(".")
            | if .[1] == "'"$build_date"'" then
                (.[2]|tonumber + 1)
            else
                0
            end
    '
