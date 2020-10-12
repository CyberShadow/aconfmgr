#!/bin/bash
source ./lib.bash

# Test 'aconfmgr diff' with owned files (reverting a modified file).

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt $'foo\n'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /testfile.txt $'bar\n'

TestPhase_Run #################################################################
aconfmgr_action_args=(/testfile.txt)
AconfDiff 2>&1 | tee "$tmp_dir"/diff-results.txt

TestPhase_Check ###############################################################
grep -Fx -- '-bar' "$tmp_dir"/diff-results.txt
grep -Fx -- '+foo' "$tmp_dir"/diff-results.txt

TestDone ######################################################################
