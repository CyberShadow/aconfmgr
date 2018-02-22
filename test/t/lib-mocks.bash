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

function install() {
	local args=()
	local mode='' owner='' group=''
	local dir=false

	local arg
	for arg in "$@"
	do
		case "$arg" in
			--mode=*)
				mode="${arg#--mode=}"
				;;
			--owner=*)
				owner="${arg#--owner=}"
				;;
			--group=*)
				group="${arg#--group=}"
				;;
			-d)
				dir=true
				;;
			-*)
				FatalError 'Unrecognized install option: %q\n' "$arg"
				;;
			*)
				args+=("$arg")
				;;
		esac
	done

	local src dst
	if $dir
	then
		test ${#args[@]} -eq 1 || FatalError 'Expected one non-option argument to install (with -d)\n'
		dst="${args[0]}"
	else
		test ${#args[@]} -eq 2 || FatalError 'Expected two non-option arguments to install (without -d)\n'
		src="${args[0]}"
		dst="${args[1]}"
	fi

	[[ "$dst" == /* ]] || FatalError 'Can'\''t install to non-absolute path\n'

	if $dir
	then
		mkdir -p "$test_data_dir"/files/"$dst"
	else
		cp "$src" "$test_data_dir"/files/"$dst"
	fi

	test -z "$mode"  || TestWriteFile "$test_data_dir"/file-props/"$dst".mode  "$mode"
	test -z "$owner" || TestWriteFile "$test_data_dir"/file-props/"$dst".owner "$owner"
	test -z "$group" || TestWriteFile "$test_data_dir"/file-props/"$dst".group "$group"
}

function cp() {
	local args=()

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

	command cp "${args[@]}"
}

function chown() {
	local args=()
	local mode='' owner='' group=''
	local dir=false

	local arg
	for arg in "$@"
	do
		case "$arg" in
			--no-dereference)
				;;
			-*)
				FatalError 'Unrecognized chown option: %q\n' "$arg"
				;;
			*)
				args+=("$arg")
				;;
		esac
	done

	test ${#args[@]} -eq 2 || FatalError 'Expected two chown arguments\n'
	local owner="${args[0]}"
	local dst="${args[1]}"

	[[ "$dst" == /* ]] || FatalError 'Can'\''t chown non-absolute path\n'

	local group=''
	if [[ "$owner" == *:* ]]
	then
		group="${owner#*:}"
		owner="${owner%:*}"
		if [[ -z "$group" ]]
		then
			group=$owner
		fi
	fi

	test -z "$owner" || TestWriteFile "$test_data_dir"/file-props"$dst".owner "$owner"
	test -z "$group" || TestWriteFile "$test_data_dir"/file-props"$dst".group "$group"
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
