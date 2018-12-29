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

for t in "${tests[@]}"
do
	docker run --rm aconfmgr /aconfmgr/test/docker/run-one.sh "$t"
done

printf '\n''Integration tests OK!''\n' 1>&2
