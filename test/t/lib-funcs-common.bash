# Test case configuration functions (common)

###############################################################################
# Test preconditions

function TestMockOnly() {
	if ((${ACONFMGR_INTEGRATION:-0}))
	then
		LogLeave
		LogLeave 'Skipping (mock-only test).\n'
		Exit 0
	fi
}

function TestIntegrationOnly() {
	if ! ((${ACONFMGR_INTEGRATION:-0}))
	then
		LogLeave
		LogLeave 'Skipping (integration-only test).\n'
		Exit 0
	fi
}

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
# Files

# Helper function - create path to and write file
function TestWriteFile() {
	local fn=$1
	local data=$2

	mkdir -p "$(dirname "$fn")"
	printf "%s" "$data" > "$fn"
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

function TestAddPackageDir() {
	local package=$1
	local path=$2
	local mode=${3:-}
	local owner=${4:-}
	local group=${5:-}

	TestAddFSObj "$package" "$path" dir '' "$mode" "$owner" "$group"
}

###############################################################################
# Packages

# Helper function - shorthand for creating and "installing" a package.
function TestAddPackage() {
	local package=$1
	local kind=$2
	local inst_as=$3

	TestCreatePackage "$package" "$kind"
	TestInstallPackage "$package" "$inst_as"
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
	diff -u /dev/stdin <(grep '^[^#]' "$config_dir"/99-unsorted.sh || true)
}

###############################################################################
# Test suite overrides

prompt_mode=paranoid
function Confirm() {
	local detail_func="$1"

	if [[ -n "$detail_func" ]]
	then
		"$detail_func"
	fi

	return 0
}
