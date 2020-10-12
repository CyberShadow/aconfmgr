# aconfmgr test suite support code.
# Sourced by test case scripts.

# aconfmgr tests work by:
# - mocking operations that inspect and modify the system (see
#   ./lib-mocks.bash)
# - helper functions that set up or inspect aconfmgr's configuration /
#   environment / results (see ./lib-funcs.bash)

source ./lib-init.bash

source ../../src/common.bash
source ../../src/save.bash
source ../../src/apply.bash
source ../../src/check.bash
source ../../src/diff.bash
source ../../src/helpers.bash

LogEnter 'Running test case %s ...\n' "$(Color C "$test_name")"
LogEnter 'Setting up test suite...\n'

for dir in "$config_dir" "$tmp_dir" "$test_data_dir"
do
	if ((${ACONFMGR_INTEGRATION:-0}))
	then
		command sudo rm -rf "$dir" # Clean up after root tests
	else
		rm -rf "$dir"
	fi
	mkdir -p "$dir"
done
unset dir

source ./lib-funcs-common.bash
if ((${ACONFMGR_INTEGRATION:-0}))
then
	if ! ((${ACONFMGR_IN_CONTAINER:-0}))
	then
		FatalError 'aconfmgr integration tests should only ever be run inside a throw-away container!''\n'
	fi

	source ./lib-funcs-integ.bash
else
	source ./lib-mocks.bash
	source ./lib-funcs-mock.bash
fi

# Don't use diff --color=auto when it's not available
if test -v BUILD_BASH && ! diff --color=auto /dev/null /dev/null 2>/dev/null
then
	diff_opts=(diff)
fi

TestInit
