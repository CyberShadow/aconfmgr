#!/bin/bash
set -eu

# Run all test scripts.
# Used for coverage analysis.

cd "$(dirname "$0")"

( cd .. && ./print-test-list.sh ) |
	while IFS= read -r test_name
	do
		$BASH ./"$test_name".sh
	done
