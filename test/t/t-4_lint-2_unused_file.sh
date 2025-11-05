#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test 'aconfmgr check' warning due to unused file.

TestPhase_Setup ###############################################################
TestWriteFile "$config_dir"/files/testfile.txt 'Test file contents'
test_expected_warnings+=1

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################

TestDone ######################################################################
