#!/bin/bash

# Handle settings
if [ -z "$RPMBUILD_SPEC" ]; then
    echo "Please provide spec file path" >&2
    exit 1
fi
flags=${RPMBUILD_FLAGS:--ba}
builddep_flags=${DNF_BUILDDEP_FLAGS:--y}

# Keep steps separate
export RPMBUILD_BASE_DIR=$(realpath "${RPMBUILD_BASE_DIR}/${RPMBUILD_DISTRO}")
echo "$RPMBUILD_BASE_DIR"

# prepare rpmbuild environment
dist_dir="${RPMBUILD_BASE_DIR%/}/dist"
mkdir -p "$dist_dir"
echo '%_topdir '"$dist_dir" >"$HOME/.rpmmacros"

# start processing
set -exo pipefail

rpmdev-setuptree

# copy all src into build dirs, just in case
rsync -qav "${SRC_DIR}/" "$dist_dir/SOURCES"
# move patches into source
if [ -d "${SRC_DIR}/patch/" ]; then
    mv -f -t "$dist_dir/SOURCES" "$dist_dir/SOURCES/patch/*"
fi

# download sources specified by url
spectool --get-files --all --sourcedir "$RPMBUILD_SPEC"

# install build dependencies
dnf builddep $builddep_flags "$RPMBUILD_SPEC"

# build rpm
rpmbuild $flags "$RPMBUILD_SPEC"

set +x
if [ -n "$RPMBUILD_GPG_KEY" ]; then
    # sign rpm
    echo "Unsetting output for signing key" >&2
    echo "$RPMBUILD_GPG_KEY" | base64 -d >"$HOME/rpm.asc"
    set -x
    gpg --batch --import "$HOME/rpm.asc"
    key=$(gpg --batch --show-keys --with-colons "$HOME/rpm.asc" | awk -F: '/^fpr/{print $10}' | head -1)
    echo "Imported key $key"
    rpmsign --addsign "--key-id=$key" "$dist_dir"/RPMS/*/*.rpm
else
    set -x
fi

# collect results
rsync -q -av "$dist_dir" ./
tree dist
