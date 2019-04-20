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
	if [[ "$1" != /* ]]
	then
		command find "$@"
	elif [[ "$1" == / ]]
	then
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
	else
		TestSimpleWrap find "$@"
	fi
}

# Simple wrapper around a command.
# Rewrite all absolute path arguments to those pointing to our virtual
# filesystem.
function TestSimpleWrap() {
	local command="$1"
	shift

	local args=()
	local arg
	for arg in "$@"
	do
		if [[ "$arg" == /* && "$arg" != /dev/* ]]
		then
			args+=("$test_data_dir"/files"$arg")
		else
			args+=("$arg")
		fi
	done

	command "$command" "${args[@]}"
}

function cat() {
	TestSimpleWrap cat "$@"
}

function readlink() {
	local result
	result="$(TestSimpleWrap readlink "$@")"
	if [[ "$result" == "$test_data_dir"/files/* ]]
	then
		result=${result#"$test_data_dir"/files}
	fi
	printf -- '%s\n' "$result"
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
	TestSimpleWrap cp "$@"
}

function mv() {
	TestSimpleWrap mv "$@"
}

function rm() {
	TestSimpleWrap rm "$@"
}

function mkdir() {
	TestSimpleWrap mkdir "$@"
}

function touch() {
	TestSimpleWrap touch "$@"
}

function ln() {
	TestSimpleWrap ln "$@"
}

function test() {
	TestSimpleWrap test "$@"
}

function tar() {
	TestSimpleWrap tar "$@"
}

if command -v bsdtar > /dev/null
then
	function bsdtar() {
		TestSimpleWrap bsdtar "$@"
	}
else
	function bsdtar() {
		TestSimpleWrap tar "$@"
	}
fi

function diff() {
	TestSimpleWrap diff "$@"
}

function chmod() {
	local args=()

	local arg
	for arg in "$@"
	do
		case "$arg" in
			# --no-dereference)
			# 	;;
			--reference=*)
				args+=($(stat --format=%a "${arg#*=}"))
				;;
			-*)
				FatalError 'Unrecognized chmod option: %q\n' "$arg"
				;;
			*)
				args+=("$arg")
				;;
		esac
	done

	test ${#args[@]} -eq 2 || FatalError 'Expected two chmod arguments\n'
	local mode="${args[0]}"
	local dst="${args[1]}"

	[[ "$dst" == /* ]] || FatalError 'Can'\''t chmod non-absolute path\n'

	# aconfmgr should not invoke chmod on symlinks
	test ! -h "$test_data_dir"/files"$dst"

	test -e "$test_data_dir"/files"$dst"

	TestWriteFile "$test_data_dir"/file-props"$dst".mode "$mode"
}

function chown() {
	local args=()

	local arg
	for arg in "$@"
	do
		case "$arg" in
			--no-dereference)
				;;
			--reference=*)
				args+=($(stat --format=%U "${arg#*=}"))
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

	test -e "$test_data_dir"/files"$dst" || test -h "$test_data_dir"/files"$dst"

	test -z "$owner" || TestWriteFile "$test_data_dir"/file-props"$dst".owner "$owner"
	test -z "$group" || TestWriteFile "$test_data_dir"/file-props"$dst".group "$group"
}

function chgrp() {
	local args=()

	local arg
	for arg in "$@"
	do
		case "$arg" in
			--no-dereference)
				;;
			-*)
				FatalError 'Unrecognized chgrp option: %q\n' "$arg"
				;;
			*)
				args+=("$arg")
				;;
		esac
	done

	test ${#args[@]} -eq 2 || FatalError 'Expected two chgrp arguments\n'
	local group="${args[0]}"
	local dst="${args[1]}"

	[[ "$dst" == /* ]] || FatalError 'Can'\''t chgrp non-absolute path\n'

	test -e "$test_data_dir"/files"$dst" || test -h "$test_data_dir"/files"$dst"

	TestWriteFile "$test_data_dir"/file-props"$dst".group "$group"
}

###############################################################################
# Packages

function TestGetAttr() {
	local root=$1
	local path=$2
	local ext=$3
	shift 3
	local query_cmd=("$@")

	local prop_path="$root"/file-props/"$path"."$ext"
	if [[ -f "$prop_path" ]]
	then
		cat "$prop_path"
	else
		"${query_cmd[@]}" "$root"/files/"$path"
	fi
}

function TestPacCheckCompare() {
	local package=$1
	local path=$2
	local paccheck_attr=$3
	local ext_attr=$4
	shift 4
	local query_cmd=("$@")

	local root1="$test_data_dir"
	local root2="$test_data_dir"/installed-packages/"$package"

	local attr1 attr2
	attr1=$(TestGetAttr "$root1" "$path" "$ext_attr" "${query_cmd[@]}")
	attr2=$(TestGetAttr "$root2" "$path" "$ext_attr" "${query_cmd[@]}")

	if [[ "$attr1" != "$attr2" ]]
	then
		printf '%s: '\''%s'\'' %s mismatch (expected %s)\n' "$package" /"$path" "$paccheck_attr" "$attr2"
		return 1
	fi
}

function TestFileMd5sum() {
	md5sum "$@" | cut -c 1-32
}

function paccheck() {
	find "$test_data_dir"/installed-packages -mindepth 1 -maxdepth 1 -printf '%P\0' | \
	while read -r -d $'\0' package
	do
		local modified=false

		local path
		local package_root="$test_data_dir"/installed-packages/"$package"
		find "$package_root"/files -mindepth 1 -printf '%P\0' | \
			while read -r -d $'\0' path
			do
				local package_path="$package_root"/files/"$path"
				# local package_prop_path="$test_data_dir"/packages/"$kind"/"$package"/file-props/"$path"
				local fs_path="$test_data_dir"/files/"$path"
				# local fs_prop_path="$test_data_dir"/file-props/"$path"

				if [[ -e "$fs_path" || -h "$fs_path" ]]
				then
					TestPacCheckCompare "$package" "$path" type                type  stat --format=%F || modified=true
					TestPacCheckCompare "$package" "$path" size                size  stat --format=%s || modified=true
					TestPacCheckCompare "$package" "$path" 'modification time' ''    stat --format=%y || modified=true
					[[ ! -f "$fs_path" || ! -f "$package_path" ]] || \
					TestPacCheckCompare "$package" "$path" md5sum              ''    TestFileMd5sum   || modified=true
					TestPacCheckCompare "$package" "$path" UID                 owner stat --format=%U || modified=true
					TestPacCheckCompare "$package" "$path" GID                 group stat --format=%G || modified=true
					TestPacCheckCompare "$package" "$path" permission          mode  stat --format=%a || modified=true
					[[ ! -h "$fs_path" || ! -h "$package_path" ]] || \
					TestPacCheckCompare "$package" "$path" 'symlink target'    ''    readlink         || modified=true
					[[ ! -e "$fs_path" ]] || \
					printf 'warning: %s: '\''%s'\'' read error (No such file or directory)\n' "$package" /"$path"
				else
					printf '%s: '\''%s'\'' missing file\n' "$package" /"$path"
				fi
			done

		if ! $modified
		then
			printf '%s: all files match database\n' "$package"
		fi
	done
}

function AconfNeedProgram() {
	: # ignore
}

function AconfRestoreFile() {
	local package=$1
	local file=$2

	local kind=native # Guess kind
	if [[ ! -d "$test_data_dir"/packages/"$kind"/"$package" ]]
	then
		kind=foreign
	fi

	local system_file="$test_data_dir"/files$file
	local package_file="$test_data_dir"/packages/"$kind"/"$package"/files"$file"

	if [[ -d "$system_file" && -d "$package_file" ]]
	then
		:
	else
		rm -f --dir "$system_file"
	fi

	if [[ -d "$package_file" ]]
	then
		mkdir --parents "$system_file"
	else
		cp --no-dereference --no-target-directory \
		   "$package_file" \
		   "$system_file"
	fi

	local prop
	for prop in owner group mode
	do
		local system_prop="$test_data_dir"/file-props"$file"."$prop"
		local package_prop="$test_data_dir"/packages/"$kind"/"$package"/file-props"$file"."$prop"
		rm -f "$system_prop"
		if [[ -e "$package_prop" ]]
		then
			cp "$package_prop" "$system_prop"
		fi
	done
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
