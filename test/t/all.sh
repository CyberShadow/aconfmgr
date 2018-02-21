#!/bin/bash
set -eu

# Run all test scripts.
# Used for coverage analysis.

cd "$(dirname "$0")"

for t in ./t-*.sh
do
	$BASH "$t"
done
