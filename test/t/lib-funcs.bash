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
	LogLeave
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
	local mode=$2
	local owner=$3
	local group=$4
	local contents=$5

	TestWriteFile "$test_data_dir"/files/"$path" "$contents"
	TestWriteFile "$test_data_dir"/file-props/"$path".type 'regular file'
	TestWriteFile "$test_data_dir"/file-props/"$path".mode "$mode"
	TestWriteFile "$test_data_dir"/file-props/"$path".owner "$owner"
	TestWriteFile "$test_data_dir"/file-props/"$path".group "$group"
}

###############################################################################
# Configuration

# Add a line to the configuration
function TestAddConfig() {
	(
		printf "%q " "$@"
		printf '\n'
	) >> "$config_dir"/50-aconfmgr-test-config.sh
}

# Verify that the generated 99-unsorted.sh configuration, stripped of
# blank and comment lines, matches stdin.
function TestExpectConfig() {
	diff -u <(grep '^[^#]' "$config_dir"/99-unsorted.sh) /dev/stdin
}
