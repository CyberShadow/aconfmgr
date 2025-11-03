#!/usr/bin/env bash
set -euo pipefail

# Runs one integration test.
# Invoked inside the Docker container by ./run-test.sh.

test=$1

cd "$(dirname "$0")"
cd ../t

if ! ((${ACONFMGR_IN_CONTAINER:-0}))
then
	printf 'This script should be run from inside the Docker container.''\n' 1>&2
	exit 1
fi

PATH="$PATH:$(ruby -e 'print Gem.user_dir')/bin"
bashcov --skip_uncovered --root=../.. ./"$test"
