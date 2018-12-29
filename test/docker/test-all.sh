#!/bin/bash
set -euo pipefail

# Build Docker image and run all integration tests.
# Invoked from test/travis.sh.

cd "$(dirname "$0")"

docker build -t aconfmgr -f Dockerfile ../..

cd ../t

for t in ./t-*.sh
do
	docker run aconfmgr /aconfmgr/test/docker/run-one.sh "$t"
done

printf '\n''Integration tests OK!''\n' 1>&2
