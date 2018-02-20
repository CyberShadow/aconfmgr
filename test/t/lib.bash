set -eEuo pipefail
shopt -s lastpipe

config_dir=../tmp/test/config
tmp_dir=../tmp/test/tmp
test_data_dir=../tmp/test/testdata

source ../../src/common.bash
source ../../src/save.bash
source ../../src/apply.bash
source ../../src/check.bash
source ../../src/helpers.bash

LogEnter 'Running test case %s...\n' "$(Color C "$(basename "$0" .sh)")"
LogEnter 'Setting up test suite...\n'

rm -rf   "$config_dir" "$tmp_dir" "$test_data_dir"
mkdir -p "$config_dir" "$tmp_dir" "$test_data_dir"

touch "$test_data_dir"/packages.txt

source ./lib-mocks.bash
source ./lib-funcs.bash
