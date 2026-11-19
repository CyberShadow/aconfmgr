#!/usr/bin/env bash
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
	make testsuite-integration

	# Fix up the filenames from the container to match the host paths.
	# Needed to get SimpleCov to include the files in the report.
	mkdir -p tmp/integ-coverage
	root=$(cd .. && pwd)
	# test/tmp/integ is mounted within the container as test/tmp
	sed 's|"/aconfmgr/|"'"$root"'/|g' tmp/integ/coverage/.resultset.json > tmp/integ-coverage/.resultset.json
	# Fail if the above no longer matches SimpleCov's output format,
	# instead of silently reporting no coverage.
	grep -qF '"'"$root"'/src/' tmp/integ-coverage/.resultset.json

	# Generate / upload the report
	bashcov --root=.. docker/empty.sh
fi
