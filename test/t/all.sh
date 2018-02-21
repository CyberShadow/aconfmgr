#!/bin/bash
set -eu

# Run all test scripts.
# If this script finishes successfully (exit status 0), the test suite
# is considered to have passed.

cd "$(dirname "$0")"

for t in ./t-*.sh
do
	$BASH "$t"
done
