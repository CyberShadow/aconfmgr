#!/usr/bin/env bash

# Build the AUR package for use in Docker.
# Invoked from the Dockerfile.

set -eEuo pipefail
shopt -s lastpipe

cd "$(dirname "$0")"

IFS=$'\n'
export LC_COLLATE=C

tmp_dir=/tmp/aconfmgr-setup
source ../../src/common.bash

pacman_opts+=(--noconfirm)

mkdir /aconfmgr-packages

chown -R nobody: aur
chmod +x /aconfmgr{,/test{,/docker{,/aur}}}
env -i -C aur setpriv --reuid=nobody --regid=nobody --clear-groups makepkg --printsrcinfo > aur/.SRCINFO
AconfMakePkgDir aur false false "$PWD"/aur

mkdir /aconfmgr-packages/aur/
cp -v aur/*.pkg.tar.* /aconfmgr-packages/aur/
# Also copy python312 package (built as dependency) to aur repo if it exists
cp -v /var/cache/pacman/pkg/python312-*.pkg.tar.* /aconfmgr-packages/aur/ 2>/dev/null || \
    cp -v /tmp/aconfmgr-setup-aur/python312/python312-*.pkg.tar.* /aconfmgr-packages/aur/ 2>/dev/null || \
    echo "Warning: python312 package not found in cache, will need to build in final image"

mkdir /aconfmgr-packages/cache/
ln -v /var/cache/pacman/pkg/*.pkg.tar.* /aconfmgr-packages/cache/

Exit 0
