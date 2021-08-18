#!/bin/bash
set -euo pipefail

# CI test script.
# Invoked from .github/workflows/test.yml.

cd "$(dirname "$0")"

if ! ((${ACONFMGR_INTEGRATION:-0}))
then
	# Run shellcheck, unit / mock tests, coverage ...
	make ci
else
	# Run integration tests
	docker/run-tests.sh

	# Fix up the filenames from the container to match the host paths.
	# Needed to get SimpleCov to include the files in the report.
	mkdir -p tmp/integ-coverage
	root=$(cd .. && pwd)
	# test/tmp/integ is mounted within the container as test/tmp
	sed 's|"/aconfmgr/|"'"$root"'/|' tmp/integ/coverage/.resultset.json > tmp/integ-coverage/.resultset.json

	# Generate / upload the report
	bashcov --root=.. docker/empty.sh
fi

# 2