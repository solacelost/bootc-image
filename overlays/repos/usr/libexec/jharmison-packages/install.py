#!/usr/bin/env python3

import click
import logging
import os
import subprocess
import sys
import yaml
from pathlib import Path


def process_file(file: Path) -> tuple[list[str], list[str]]:
    """Processes the file, returning packages and excludes"""
    logging.debug(f"Processing package file: {file}")
    with open(file) as f:
        data = yaml.safe_load(f)
    packages = [
        package
        for package_line in [package_line.split() for package_line in data.get("packages", [])]
        for package in package_line
    ]
    excludes = [
        exclude
        for exclude_line in [exclude_line.split() for exclude_line in data.get("excludes", [])]
        for exclude in exclude_line
    ]
    return (
        packages,
        excludes,
    )


@click.command(context_settings=dict(help_option_names=["-h", "--help"], ignore_unknown_options=True))
@click.option(
    "-d",
    "--directory",
    help="Directory to search for yaml files in, supporting a package installation",
    type=click.Path(exists=True, readable=True, file_okay=False, dir_okay=True),
    default="/usr/share/doc/jharmison-packages",
)
@click.option(
    "-p",
    "--package-file",
    help="Specify one file in DIRECTORY to install from, without iterating through them all",
    type=str,
    default=None,
)
@click.option(
    "-f",
    "--file",
    help="Specific a file to install packages from, rather than all discoverable packages from some directory",
    type=click.Path(exists=True, readable=True, file_okay=True, dir_okay=False),
    metavar="FILE",
    default=None,
)
@click.option(
    "-l",
    "--list-packages",
    help="List packages, instead of installing them",
    is_flag=True,
    default=False,
)
@click.option(
    "-v",
    "--verbose",
    count=True,
    help="Increase verbosity (specify multiple times for more)",
)
@click.argument("args", nargs=-1)
def cli(directory, package_file, file, list_packages, verbose, args):
    """Template and run dnf install commands using levels of packages"""
    logging.basicConfig(stream=sys.stderr, level=40 - (min(3, verbose + 2) * 10))
    directory = Path(directory)

    packages = []
    excludes = []
    if file is not None:
        packages, excludes = process_file(file)
    elif package_file is not None:
        file = directory.joinpath(package_file)
        if not (file.exists() and file.is_file()):
            file = directory.joinpath(f"{package_file}.yaml")
            if not (file.exists() and file.is_file()):
                raise FileNotFoundError(f"Unable to identify {file} in {directory}")
        packages, excludes = process_file(file)
    else:
        _, _, files = next(os.walk(directory))
        for file in files:
            if file.endswith(".yaml") or file.endswith(".yml"):
                f_packages, f_excludes = process_file(directory.joinpath(file))
                packages.extend(f_packages)
                excludes.extend(f_excludes)

    packages.sort()
    excludes.sort()
    if list_packages:
        click.echo(yaml.dump(dict(packages=packages, excludes=excludes)))
        exit(0)

    if not packages:
        logging.warning("Not provided any packages to install, exiting early")
        exit(0)

    cmd = ["dnf", "--assumeyes"]
    if excludes:
        cmd.append(f'--exclude={",".join(excludes)}')
    cmd.extend(["install", "--allowerasing"])
    cmd.extend(args)
    cmd.extend(packages)
    logging.debug(f'Executing: {" ".join(cmd)}')
    result = subprocess.run(cmd)
    exit(result.returncode)


if __name__ == "__main__":
    cli()
