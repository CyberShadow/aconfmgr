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
source ../../src/helpers.bash

LogEnter 'Running test case %s...\n' "$(Color C "$test_name")"
LogEnter 'Setting up test suite...\n'

rm -rf   "$config_dir" "$tmp_dir" "$test_data_dir"
mkdir -p "$config_dir" "$tmp_dir" "$test_data_dir"

touch "$test_data_dir"/packages.txt

source ./lib-mocks.bash
source ./lib-funcs.bash
