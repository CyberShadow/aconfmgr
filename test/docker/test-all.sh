#!/bin/bash
set -euo pipefail

# Build Docker image and run all integration tests.
# Invoked from test/travis.sh.

cd "$(dirname "$0")"

docker build -t aconfmgr -f Dockerfile ../..

docker run aconfmgr /aconfmgr/test/docker/run.sh

printf '\n''Integration tests OK!''\n' 1>&2
