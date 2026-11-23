#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test 'aconfmgr diff' with a file which matches the configuration.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt $'foo\n'
# shellcheck disable=SC2016
TestAddConfig 'echo foo > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
TestDiff 0 /testfile.txt

TestPhase_Check ###############################################################
! grep -q '^[-+]' "$test_dir"/diff-results.txt

TestDone ######################################################################
