# Test case configuration functions

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

function TestAddPackage() {
	local name=$1
	local kind=$2
	local inst_as=$3

	printf '%s %s %s\n' "$name" "$kind" "$inst_as" >> "$test_data_dir"/packages.txt
}
