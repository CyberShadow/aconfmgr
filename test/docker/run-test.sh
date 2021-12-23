#!/bin/bash
set -eEuo pipefail
shopt -s lastpipe

# Run specified integration test.
# Invoked from ../GNUmakefile.

cd "$(dirname "$0")"/../t

test=$1

# shellcheck disable=SC2174
mkdir -p -m755 ../tmp/integ  # Integration tmp directory

args=(
	docker run
	--rm
	-v "$PWD/../..:/aconfmgr:ro"
	-v "$PWD/../tmp/integ:/aconfmgr/test/tmp:rw"
	--add-host aur.archlinux.org:127.0.0.1
	-e GITHUB_ACTIONS
	--env 'ACONFMGR_INTEGRATION=1'
	--env 'ACONFMGR_IN_CONTAINER=1'
	--user aconfmgr
	aconfmgr
	/aconfmgr/test/docker/run-test-inner.sh "$test"
) ; "${args[@]}"
