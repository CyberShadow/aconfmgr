# Common test suite configuration.
# Sourced by test case scripts (through lib.sh),
# and mock programs (through lib-init-mock.bash).

set -eEuo pipefail
shopt -s lastpipe

IFS=$'\n'
export LC_COLLATE=C

test_globals_initial=$(comm -13 <(compgen -e | sort) <(compgen -v | sort))

if [[ -n ${ACONFMGR_CURRENT_TEST+x} ]]
then
	test_name=$ACONFMGR_CURRENT_TEST
else
	test_name=$(basename "$0" .sh)
fi
export ACONFMGR_CURRENT_TEST=$test_name

test_dir=../tmp/test/$test_name
config_dir=$test_dir/config
tmp_dir=$test_dir/tmp
test_data_dir=$test_dir/testdata
test_aur_dir=$test_dir/aur
