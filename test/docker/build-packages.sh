#!/bin/bash

# Build some packages used in the test suite.
# Invoked from the Dockerfile.

# Set up paths
# (e.g. needed for path to perl's prove, needed to build pacutils).
source /etc/profile

set -eEuo pipefail
shopt -s lastpipe

cd "$(dirname "$0")"

IFS=$'\n'
export LC_COLLATE=C

tmp_dir=/tmp/aconfmgr-setup
source ../../src/common.bash

pacman_opts+=(--noconfirm)

mkdir /aconfmgr-packages

packages=(pacutils)
for package in "${packages[@]}"
do
	file=$(AconfNeedPackageFile "$package")
	cp "$file" /aconfmgr-packages/"$package".pkg.tar.xz
done

Exit 0
