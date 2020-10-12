#!/bin/bash
source ./lib.bash

# Test 'aconfmgr diff' with owned files (editing an unmodified file).

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt $'foo\n'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /testfile.txt $'foo\n'
# shellcheck disable=SC2016
TestAddConfig 'echo bar > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
aconfmgr_action_args=(/testfile.txt)
AconfDiff 2>&1 | tee "$tmp_dir"/diff-results.txt

TestPhase_Check ###############################################################
grep -Fx -- '-foo' "$tmp_dir"/diff-results.txt
grep -Fx -- '+bar' "$tmp_dir"/diff-results.txt

TestDone ######################################################################
