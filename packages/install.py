import logging
import os
import subprocess
import sys
import yaml

logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

pkgs = []
excludes = []
for _, _, files in os.walk('/packages'):
    for file in files:
        if file.endswith('.yaml') or file.endswith('.yml'):
            logging.debug(f'Processing package file: {file}')
            with open(f'/packages/{file}') as f:
                data = yaml.safe_load(f)
            for package_line in data.get('packages', []):
                for package in package_line.split():
                    pkgs.append(package)
            for exclude_line in data.get('exclude', []):
                for exclude in exclude_line.split():
                    excludes.append(exclude)

cmd = ['dnf', '--assumeyes']
if excludes:
    cmd.append(f'--exclude={",".join(excludes)}')
cmd.extend(['install', '--allowerasing'])
cmd.extend(pkgs)
logging.debug(f'Executing: {" ".join(cmd)}')
result = subprocess.run(cmd)
exit(result.returncode)
