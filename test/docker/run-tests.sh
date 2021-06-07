#!/bin/bash
set -eEuo pipefail
shopt -s lastpipe

# Build Docker image and run all integration tests.
# Invoked from test/ci.sh.

cd "$(dirname "$0")"

make -C .. docker-image

cd ../t

tests=()
if [[ $# -gt 0 ]]
then
	tests=("$@")
else
	( cd .. && ./print-test-list.sh ) |
		sed 's/$/.sh/' |
		mapfile -t tests
fi

# Integration tmp directory
mkdir -p ../tmp/integ
chmod a+x ../tmp/integ

for t in "${tests[@]}"
do
	args=(
		docker run
		--rm
		-v "$PWD/../..:/aconfmgr:ro"
		-v "$PWD/../tmp/integ:/aconfmgr/test/tmp:rw"
		--add-host aur.archlinux.org:127.0.0.1
		--env 'ACONFMGR_INTEGRATION=1'
		--env 'ACONFMGR_IN_CONTAINER=1'
		--user aconfmgr
		aconfmgr
		/aconfmgr/test/docker/run-one.sh "$t"
	) ; "${args[@]}"
done

printf 'Integration tests OK!\n' 1>&2
