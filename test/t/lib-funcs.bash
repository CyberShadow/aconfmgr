# Test case configuration functions

###############################################################################
# Test phases

function TestPhase_Setup() {
	LogLeave
	LogEnter 'Setting up test case...\n'
}

function TestPhase_Run() {
	LogLeave
	LogEnter 'Running test...\n'
}

function TestPhase_Check() {
	LogLeave
	LogEnter 'Checking results...\n'
}

function TestDone() {
	LogLeave
	test "$log_indent" == :: || FatalError 'Unbalanced log level!\n'
	LogLeave 'Test %s: %s!\n' "$(Color C "$test_name")" "$(Color G success)"
	Exit 0
}

###############################################################################
# Packages

function TestAddPackage() {
	local name=$1
	local kind=$2
	local inst_as=$3

	printf '%s\t%s\t%s\n' "$name" "$kind" "$inst_as" >> "$test_data_dir"/packages.txt
}

function TestCreatePackageFile() {
	local package=$1
	local version=1.0 # $2
	local arch=x86_64 # $3

	local package_file="$test_data_dir"/files/var/cache/pacman/pkg/"$package"-"$version"-"$arch".pkg.tar.xz
	mkdir -p "$test_data_dir"/files/var/cache/pacman/pkg

	printf 'pkgname = %s\n' "$package" > "$test_data_dir"/packages/"$package"/.PKGINFO
	tar --create -f "$package_file" -C "$test_data_dir"/packages/"$package" .PKGINFO

	local path
	find "$test_data_dir"/packages/"$package"/files -mindepth 1 -maxdepth 1 -printf '%P\0' | \
		while read -r -d $'\0' path
		do
			# local package_path="$test_data_dir"/packages/"$package"/files/"$path"
			local package_prop_path="$test_data_dir"/packages/"$package"/file-props/"$path"

			local opts=()
			if [[ -e "$package_prop_path".owner ]] ; then opts+=(--owner "$(cat "$package_prop_path".owner)") ; fi
			if [[ -e "$package_prop_path".group ]] ; then opts+=(--group "$(cat "$package_prop_path".group)") ; fi
			if [[ -e "$package_prop_path".mode  ]] ; then opts+=(--mode  "$(cat "$package_prop_path".mode )") ; fi

			tar --append -f "$package_file" "${opts[@]}" -C "$test_data_dir"/packages/"$package"/files "$path"
		done
}

###############################################################################
# Files

# Helper function - create path to and write file
function TestWriteFile() {
	local fn=$1
	local data=$2

	mkdir -p "$(dirname "$fn")"
	printf "%s" "$data" > "$fn"
}

function TestAddFSObj() {
	local package=$1 # empty string to add to filesystem
	local path=$2
	local type=$3 # file, dir, link
	local contents=$4 # file contents or link data
	local mode=${5:-}
	local owner=${6:-}
	local group=${7:-}

	local root
	if [[ -z "$package" ]]
	then
		root="$test_data_dir"
	else
		root="$test_data_dir"/packages/"$package"
	fi

	case "$type" in
		file)
			TestWriteFile "$root"/files/"$path" "$contents"
			;;
		dir)
			test -z "$contents" || FatalError 'Attempting to create directory with non-empty contents\n'
			mkdir -p "$root"/files/"$path"
			;;
		link)
			local fn="$test_data_dir"/files/"$path"
			mkdir -p "$(dirname "$fn")"
			ln -s "$contents" "$fn"
			;;
		*)
			FatalError 'Unknown filesystem object type %s\n' "$type"
			;;
	esac

	if [[ -n "$mode"  ]] ; then TestWriteFile "$root"/file-props/"$path".mode  "$mode"  ; fi
	if [[ -n "$owner" ]] ; then TestWriteFile "$root"/file-props/"$path".owner "$owner" ; fi
	if [[ -n "$group" ]] ; then TestWriteFile "$root"/file-props/"$path".group "$group" ; fi
}

# Add a file to the virtual filesystem.
function TestAddFile() {
	local path=$1
	local contents=$2
	local mode=${3:-}
	local owner=${4:-}
	local group=${5:-}

	TestAddFSObj '' "$path" file "$contents" "$mode" "$owner" "$group"
}

# Add a directory to the virtual filesystem.
function TestAddDir() {
	local path=$1
	local mode=${2:-}
	local owner=${3:-}
	local group=${4:-}

	TestAddFSObj '' "$path" dir '' "$mode" "$owner" "$group"
}

# Add a symlink to the virtual filesystem.
function TestAddLink() {
	local path=$1
	local target=$2
	local owner=${3:-}
	local group=${4:-}

	TestAddFSObj '' "$path" link "$target" '' "$owner" "$group"
}

function TestAddPackageFile() {
	local package=$1
	local path=$2
	local contents=$3
	local mode=${4:-}
	local owner=${5:-}
	local group=${6:-}

	TestAddFSObj "$package" "$path" file "$contents" "$mode" "$owner" "$group"
}

###############################################################################
# Configuration

# Add a line to the configuration
function TestAddConfig() {
	(
		printf "%s " "$@"
		printf '\n'
	) >> "$config_dir"/50-aconfmgr-test-config.sh
}

# Verify that the generated 99-unsorted.sh configuration, stripped of
# blank and comment lines, matches stdin.
function TestExpectConfig() {
	touch "$config_dir"/99-unsorted.sh
	diff -u <(grep '^[^#]' "$config_dir"/99-unsorted.sh || true) /dev/stdin
}
