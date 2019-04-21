#!/bin/bash

# Build the AUR package for use in Docker.
# Invoked from Dockerfile.aur.

set -eEuo pipefail
shopt -s lastpipe

cd "$(dirname "$0")"

IFS=$'\n'
export LC_COLLATE=C

tmp_dir=/tmp/aconfmgr-setup
source ../../src/common.bash
source ../../src/distros/arch.bash

pacman_opts+=(--noconfirm)

mkdir /aconfmgr-packages

chown -R nobody: aur
env -i -C aur su -s /bin/bash nobody -c 'makepkg --printsrcinfo' > aur/.SRCINFO
AconfMakePkgDir aur false false "$PWD"/aur

mkdir /aconfmgr-packages/aur/
cp -v aur/*.pkg.tar.xz /aconfmgr-packages/aur/

mkdir /aconfmgr-packages/cache/
ln -v /var/cache/pacman/pkg/*.pkg.tar.xz /aconfmgr-packages/cache/

Exit 0
