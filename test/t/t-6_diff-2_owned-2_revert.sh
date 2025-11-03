#!/usr/bin/env bash
source ./lib.bash

# Test 'aconfmgr diff' with owned files (reverting a modified file).

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt $'foo\n'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /testfile.txt $'bar\n'

TestPhase_Run #################################################################
aconfmgr_action_args=(/testfile.txt)
AconfDiff 2>&1 | tee "$test_dir"/diff-results.txt

TestPhase_Check ###############################################################
grep -Fx -- '-bar' "$test_dir"/diff-results.txt
grep -Fx -- '+foo' "$test_dir"/diff-results.txt

TestDone ######################################################################
