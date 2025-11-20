#!/bin/bash


src="$(dirname "$(dirname "$(realpath "$0")")")/overlays/base/usr/local/share/nvim-config/"
set -x

rm -rf ~/.config/nvim
mkdir -p ~/.config/nvim
rsync -rltpD "$src" ~/.config/nvim/
