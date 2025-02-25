#!/usr/bin/env python3

import argparse
import logging
import sys

from pathlib import Path

from protontricks import get_steam_apps, find_steam_installations, select_steam_installation, get_steam_lib_paths, find_steam_compat_tool_app


logging.basicConfig(stream=sys.stderr, level=logging.WARNING)

parser = argparse.ArgumentParser()
parser.add_argument("--id", help="The Steam game ID for the game you're looking up")

args = parser.parse_args()

# 1. Find Steam path
steam_installations = find_steam_installations()
if not steam_installations:
    logging.error("Steam installation directory could not be found.")
    exit(1)

steam_path, steam_root = select_steam_installation(steam_installations)
if not steam_path:
    logging.error("No Steam installation was selected.")
    exit(2)

# 2. Find any Steam library folders
steam_lib_paths = get_steam_lib_paths(steam_path)

steam_apps = get_steam_apps(
    steam_root=steam_root, steam_path=steam_path,
    steam_lib_paths=steam_lib_paths
)

for app in steam_apps:
    if app.appid == args.id or str(app.appid) == args.id:
        if app.prefix_path_exists:
            print(app.prefix_path)
