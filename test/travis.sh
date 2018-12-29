#!/bin/bash
set -euo pipefail

# Travis CI test script.
# Invoked from .travis.yml.

cd "$(dirname "$0")"

if ((${ACONFMGR_INTEGRATION:-0}))
then
	# Run integration tests
	docker/test-all.sh
else
	# Run shellcheck, unit / mock tests, coverage ...
	make ci BUILD_BASH=1
fi
