#!/bin/bash

# Perform some final Docker image preparations.
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
AconfNeedProgram paccheck pacutils y
Exit 0
