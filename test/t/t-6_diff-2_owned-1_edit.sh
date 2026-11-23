#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test 'aconfmgr diff' with owned files (editing an unmodified file).

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt $'foo\n'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /testfile.txt $'foo\n'
# shellcheck disable=SC2016
TestAddConfig 'echo bar > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
TestDiff 1 /testfile.txt

TestPhase_Check ###############################################################
grep -Fx -- '-foo' "$test_dir"/diff-results.txt
grep -Fx -- '+bar' "$test_dir"/diff-results.txt

TestDone ######################################################################
