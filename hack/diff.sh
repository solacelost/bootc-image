#!/bin/bash

_old="${1}"
_new="${2}"
repo="${3:-registry.jharmison.com/library/fedora-bootc}"
if [[ -z "$_old" ]] || [[ -z "$_new" ]]; then
    echo "usage: $0 OLD_TAG_OR_MANIFEST_HASH NEW_TAG_OR_MANIFEST_HASH [IMAGE_REPOSITORY]" >&2
    exit 1
fi
if [[ $_old == *":"* ]]; then
    old="$repo@$_old"
else
    old="$repo:$_old"
fi
if [[ $_new == *":"* ]]; then
    new="$repo@$_new"
else
    new="$repo:$_new"
fi

set -ex

nvim -c 'set diffopt+=context:0' -Rd <(podman run --rm --entrypoint dnf "$new" list --installed) <(podman run --rm --entrypoint dnf "$old" list --installed)
