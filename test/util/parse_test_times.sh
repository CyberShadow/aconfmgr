#!/usr/bin/env bash
set -eEuo pipefail

# Read a GitHub Actions log file (or files) from stdin,
# and parse it in order to extract the durations of each test.

printf 'declare -A test_durations\n'
printf 'test_durations=(\n'

while IFS= read -r line
do
	# Note: the .? at the end is for the carriage return that GitHub adds
	if   [[ "$line" =~ ^(....-..-..T..:..:..\........Z)\ \[0K\[1\;34m:\ \[1\;39mRunning\ test\ case\ \[1\;36m(.*)\[1\;39m\ \.\.\..?$ ]]
	then
		start_time=$(date -d "${BASH_REMATCH[1]}" +%s%N)
		test_name=${BASH_REMATCH[2]}
	elif [[ "$line" =~ ^(....-..-..T..:..:..\........Z)\ \[0m\[0K\[1\;34m::\ \[1\;39mTest\ \[1\;36m(.*)\[1\;39m:\ \[1\;32msuccess\[1\;39m!.?$ ]]
	then
		if [[ "${BASH_REMATCH[2]}" != "$test_name" ]]
		then
			printf 'Desynchronization: Expected end of test %q, got end of test %q\n' "$test_name" "${BASH_REMATCH[2]}"
			exit 1
		fi

		end_time=$(date -d "${BASH_REMATCH[1]}" +%s%N)

		printf '\t[%s]=%d\n' "$test_name" $((end_time - start_time))

		test_name=
	fi
done

printf ')\n'
