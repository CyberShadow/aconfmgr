#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test that saving warns about orphan packages,
# which are not saved (and which applying would remove).

TestPhase_Setup ###############################################################
TestAddPackage test-explicit-package native explicit
TestAddPackage test-dependency-package native dependency
TestAddPackage test-orphan-package native orphan

TestPhase_Run #################################################################
AconfSave 2> "$test_data_dir"/save.log

TestPhase_Check ###############################################################
command cat "$test_data_dir"/save.log 1>&2

TestExpectConfig <<EOF
AddPackage test-explicit-package # Dummy aconfmgr test suite package: subtitle
EOF

command grep -F 'Found' "$test_data_dir"/save.log | command grep -F 'orphan packages' > "$test_data_dir"/warning.log
command grep -qF 'test-orphan-package' "$test_data_dir"/warning.log
# A dependency which is still required is not an orphan.
! command grep -qF 'test-dependency-package' "$test_data_dir"/warning.log

TestDone ######################################################################
