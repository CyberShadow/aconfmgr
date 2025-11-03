#!/usr/bin/env bash
set -eEuo pipefail

# This script performs code style checks (in addition to ShellCheck).

files=("$@")

# Code style

if grep -E ';\s*(then|do)$' "${files[@]}"
then
	echo 'Please use line breaks to separate if/then, while/do etc.' 1>&2
	exit 1
fi

# Test suite names

if grep -vE '^t/[tm](-[0-9](_[a-z]+)+)+\.sh$' <(printf '%s\n' "${files[@]}" | grep '^t/.-')
then
	echo 'Test name is incorrectly formatted.' 1>&2
	exit 1
fi

# Test suite numbers

function TestNumbers() {
	printf '%s\n' "${files[@]}" |
		grep '^t/[tm]-' |
		tr -dc '0-9\n' |
		LC_ALL=C sort
}

if ! diff -u \
	 <(TestNumbers | uniq) \
	 <(TestNumbers)
then
	echo 'Test number collision.' 1>&2
	exit 1
fi

# Test suite descriptions

function TestDescriptions() {
	local file line
	printf '%s\n' "${files[@]}" |
		grep '^t/t-' |
		while read -r file
		do
			local in_description=false
			while IFS= read -r line
			do
				if [[ "$line" =~ ^#\ .* && "$line" != \#\ shellcheck\ * ]]
				then
					in_description=true
					printf '%s' "$line"
				elif $in_description
				then
					break
				fi
			done < "$file"
			if ! $in_description
			then
				printf 'Test %q does not have a description.\n' "$file" 1>&2
			fi
			printf '\n'
		done |
		LC_ALL=C sort
}

if ! diff -u \
	 <(TestDescriptions | uniq) \
	 <(TestDescriptions)
then
	echo 'Duplicate test descriptions.' 1>&2
	exit 1
fi
