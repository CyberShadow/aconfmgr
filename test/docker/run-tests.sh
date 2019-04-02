#!/bin/bash
set -euo pipefail

# Build Docker image and run all integration tests.
# Invoked from test/travis.sh.

cd "$(dirname "$0")"

make -C .. docker-image

cd ../t

tests=()
if [[ $# -gt 0 ]]
then
	tests=("$@")
else
	tests=(t-*.sh)
fi

# Integration tmp directory
mkdir -p ../tmp/integ

for t in "${tests[@]}"
do
	args=(
		docker run
		--rm
		-v "$PWD/../..:/aconfmgr:ro"
		-v "$PWD/../tmp/integ:/aconfmgr/test/tmp:rw"
		--env 'ACONFMGR_INTEGRATION=1'
		--env 'ACONFMGR_IN_CONTAINER=1'
		--user aconfmgr
		aconfmgr
		/aconfmgr/test/docker/run-one.sh "$t"
	) ; "${args[@]}"
done

printf 'Integration tests OK!\n' 1>&2
