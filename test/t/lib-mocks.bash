# Mocked system introspection programs

# We can redefine some mocked programs as functions.

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

function find() {
	if [[ $1 != / ]]
	then
		command "find" "$@"
	else
		# Assume this is the find invocation for finding lost files in
		# common.sh.
		cat "$test_data_dir"/find_lost_files.txt
	fi
}

function cat() {
	if [[ $# -eq 0 ]]
	then
		/bin/cat
	else
		for arg in "$@"
		do
			if [[ "$arg" == /* ]]
			then
				command cat "$test_data_dir"/file-contents/"$arg"
			else
				command cat "$arg"
			fi
		done
	fi
}

function paccheck() {
	: # TODO
}

function AconfNeedProgram() {
	: # ignore
}

# Some programs cannot be functions because they are executed from a
# condition (e.g. `if prog; then` or `prog || failed=true`). This
# disables `set -e` in a way that is impossible to re-enable (bash
# CMD_IGNORE_RETURN flag), so they must be separate executables.

export PATH=$PWD/mocks:$PATH
