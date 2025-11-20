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


@click.command(context_settings=dict(help_option_names=["-h", "--help"]))
@click.option(
    "-l",
    "--max-level",
    help="The level between 0 and 100 to install to, inclusively, starting from the  min-level",
    type=click.IntRange(0, 100),
    default=50,
    show_default=True,
)
@click.option(
    "-m",
    "--min-level",
    help="The level between 0 and 100 to install starting at, inclusively, continuing to max-level",
    type=click.IntRange(0, 100),
    default=0,
    show_default=True,
)
@click.option(
    "-f",
    "--file",
    help="Specific a file to install packages from, rather than using a version range and the default manifests",
    type=click.Path(exists=True, readable=True, file_okay=True, dir_okay=False),
    metavar="FILE",
    default=None,
)
@click.option(
    "-v",
    "--verbose",
    count=True,
    help="Increase verbosity (specify multiple times for more)",
)
def cli(max_level, min_level, file, verbose):
    """Template and run dnf install commands using levels of packages"""
    logging.basicConfig(stream=sys.stderr, level=40 - (min(3, verbose + 2) * 10))

    packages = []
    excludes = []
    if file is not None:
        packages, excludes = process_file(file)
    else:
        _, pardirs, _ = next(os.walk("/packages"))
        for leveldir in pardirs:
            try:
                if int(leveldir) >= min_level and int(leveldir) <= max_level:
                    for _, _, files in os.walk(f"/packages/{leveldir}"):
                        for file in files:
                            if file.endswith(".yaml") or file.endswith(".yml"):
                                f_packages, f_excludes = process_file(Path(f"/packages/{leveldir}/{file}"))
                                packages.extend(f_packages)
                                excludes.extend(f_excludes)
            except ValueError:
                pass

    cmd = ["dnf", "--assumeyes"]
    if excludes:
        cmd.append(f'--exclude={",".join(excludes)}')
    cmd.extend(["install", "--allowerasing"])
    cmd.extend(packages)
    logging.debug(f'Executing: {" ".join(cmd)}')
    result = subprocess.run(cmd)
    exit(result.returncode)


if __name__ == "__main__":
    cli()
