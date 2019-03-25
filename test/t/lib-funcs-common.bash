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
	TestPhase_RunHook
}

function TestPhase_Check() {
	LogLeave
	LogEnter 'Checking results...\n'
}

test_globals_whitelist=(

	# Set by bash
	COLUMNS
	LINES
	FUNCNAME
	BASH_REMATCH

	# Terminal codes (common.bash)
	ANSI_clear_line
	ANSI_color_B
	ANSI_color_C
	ANSI_color_G
	ANSI_color_M
	ANSI_color_R
	ANSI_color_W
	ANSI_color_Y
	ANSI_reset

	# Defaults inherited from environment (common.bash)
	PACMAN

	# Command-line settings
	aur_helper
	prompt_mode
	skip_inspection
	verbose

	# Config-tweakable settings
	default_file_mode
	ignore_paths
	priority_files

	warn_file_count_threshold
	warn_size_threshold
	warn_tmp_df_threshold

	# Internal state (paths)
	config_dir
	output_dir
	system_dir
	tmp_dir

	# Internal state (AconfAnalyzeFiles)
	system_only_files
	changed_files
	config_only_files
	output_file_props
	system_file_props
	orig_file_props
	all_file_property_kinds

	# Internal state (AconfCompareFileProps)
	system_only_file_props
	changed_file_props
	config_only_file_props

	# Internal state (AconfCompile)
	packages
	installed_packages
	foreign_packages
	installed_foreign_packages

	# Internal state (AconfCompileOutput)
	ignore_packages
	ignore_foreign_packages
	used_files

	# Internal state (AconfCompileSystem)
	ignored_dirs

	# Internal state (misc.)
	aur_helpers
	base_devel_installed
	lint_config
	log_indent
	config_warnings
	file_property_kind_exists

	# Tool command-line options
	aurman_opts
	diff_opts
	makepkg_opts
	pacaur_opts
	pacman_opts
	yaourt_opts
	yay_opts

	# Test suite
	test_name
	test_data_dir
	test_fs_root
	test_globals_initial
	test_globals_whitelist
	test_adopted_packages
)

function TestDone() {
	LogLeave

	# Final checks

	# Check that log nesting level is balanced
	test "$log_indent" == :: || FatalError 'Unbalanced log level!\n'

	# Check for stray global variables
	(
		comm -13 <(compgen -e | sort) <(compgen -v | sort) \
			| comm -23 /dev/stdin <(echo "$test_globals_initial") \
			| comm -23 /dev/stdin <(echo "${test_globals_whitelist[*]}" | sort) \
			| diff /dev/null /dev/stdin
	) || FatalError 'Unknown stray global variables found!\n'

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
		LogEnter 'Details:\n'
		"$detail_func"
		LogLeave ''
	fi

	return 0
}
