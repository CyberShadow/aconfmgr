#!/bin/bash
set -euo pipefail

# Runs one integration test.
# Invoked inside the Docker container by ./run-tests.sh.

test=$1

cd "$(dirname "$0")"
cd ../t

export ACONFMGR_INTEGRATION=1
export ACONFMGR_IN_CONTAINER=1

./"$test"
