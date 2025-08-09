#!/bin/bash


src="$(dirname "$(dirname "$(realpath "$0")")")/overlays/base/usr/local/share/nvim-config/"
rm -rf ~/.config/nvim
mkdir -p ~/.config/nvim

set -x
rsync -rltpD "$src" ~/.config/nvim/
