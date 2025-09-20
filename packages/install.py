import click
import logging
import os
import subprocess
import sys
import yaml


@click.command(context_settings=dict(help_option_names=["-h", "--help"]))
@click.option(
    '-l',
    '--max-level',
    help='The level between 0 and 100 to install to, inclusively, starting from the  min-level',
    type=click.IntRange(0, 100),
    default=50,
    show_default=True
)
@click.option(
    '-m',
    '--min-level',
    help='The level between 0 and 100 to install starting at, inclusively, continuing to max-level',
    type=click.IntRange(0, 100),
    default=0,
    show_default=True
)
@click.option(
    "-v",
    "--verbose",
    count=True,
    help="Increase verbosity (specify multiple times for more)",
)
def cli(max_level, min_level, verbose):
    """Template and run dnf install commands using levels of packages"""
    logging.basicConfig(stream=sys.stderr, level=40 - (min(3, verbose+2) * 10))

    pkgs = []
    excludes = []
    _, pardirs, _ = next(os.walk('/packages'))
    for leveldir in pardirs:
        try:
            if int(leveldir) >= min_level and int(leveldir) <= max_level:
                for _, _, files in os.walk(f'/packages/{leveldir}'):
                    for file in files:
                        if file.endswith('.yaml') or file.endswith('.yml'):
                            logging.debug(f'Processing package file: {file}')
                            with open(f'/packages/{leveldir}/{file}') as f:
                                data = yaml.safe_load(f)
                            for package_line in data.get('packages', []):
                                for package in package_line.split():
                                    pkgs.append(package)
                            for exclude_line in data.get('exclude', []):
                                for exclude in exclude_line.split():
                                    excludes.append(exclude)
        except ValueError:
            pass

    cmd = ['dnf', '--assumeyes']
    if excludes:
        cmd.append(f'--exclude={",".join(excludes)}')
    cmd.extend(['install', '--allowerasing'])
    cmd.extend(pkgs)
    logging.debug(f'Executing: {" ".join(cmd)}')
    result = subprocess.run(cmd)
    exit(result.returncode)


if __name__ == "__main__":
    cli()
