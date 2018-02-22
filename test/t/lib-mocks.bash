# Mocked system introspection programs

# We can redefine some mocked programs as functions.

###############################################################################
# General

function sudo() {
	"$@"
}

function sh() {
	test $# -eq 2 || FatalError 'Expected two sh arguments\n'
	test "$1" == '-c' || FatalError 'Expected -c as first sh argument\n'
	eval "$2"
}

function stdbuf() {
	test $# -gt 2 || FatalError 'Expected two or more stdbuf arguments\n'
	test "$1" == '-o0' || FatalError 'Expected -o0 as first stdbuf argument\n'
	shift
	"$@"
}

###############################################################################
# Files

function find() {
	if [[ "$1" != / ]]
	then
		command "find" "$@"
	else
		# Assume this is the find invocation for finding lost files in
		# common.sh.  Prefix arguments with our "virtual filesystem"
		# directory and then remove it from the output.

		args=()
		local arg
		for arg in "$@"
		do
			if [[ "$arg" == /* ]]
			then
				args+=("$test_data_dir"/files"$arg")
			else
				args+=("$arg")
			fi
		done

		mkdir -p "$test_data_dir"/files

		local line
		command find "${args[@]}" | \
			while read -r -d $'\0' line
			do
				file=${line:1}
				action=${line:0:1}
				if [[ "$file" == "$test_data_dir"/files/* ]]
				then
					file=${file#$test_data_dir/files}
				else
					FatalError 'Unexpected find output line: %s\n' "$line"
				fi
				printf '%s%s\0' "$action" "$file"
			done
	fi
}

function cat() {
	if [[ $# -eq 0 ]]
	then
		/bin/cat
	else
		local arg
		for arg in "$@"
		do
			if [[ "$arg" == /* ]]
			then
				command cat "$test_data_dir"/files"$arg"
			else
				command cat "$arg"
			fi
		done
	fi
}

function readlink() {
	test $# -eq 1 || FatalError 'Expected one readlink argument\n'
	local arg=$1

	if [[ "$arg" == /* ]]
	then
		command readlink "$test_data_dir"/files"$arg"
	else
		command readlink "$arg"
	fi
}

###############################################################################
# Packages

function paccheck() {
	cat "$test_data_dir"/modified-files.txt
}

function AconfNeedProgram() {
	: # ignore
}

# Some mocked commands cannot be functions, if:
#
# - They are executed from a condition (e.g. `if prog; then` or `prog
#   || failed=true`). This disables `set -e` in a way that is impossible
#   to re-enable (bash CMD_IGNORE_RETURN flag), so they must be separate
#   executables.
#
# - They are executed via xargs, or some other method that is
#   unreasonably cumbersome to mock as a function.
#
# For such cases, the implementation lies in a separate executable
# file, the path to which we prepend to the system PATH.

export PATH=$PWD/mocks:$PATH
