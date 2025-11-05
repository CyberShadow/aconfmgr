#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test configuration parsing warning due to relative paths.

TestPhase_Setup ###############################################################
TestWriteFile "$config_dir"/files/src.txt 'Test file contents'
TestAddConfig CopyFileTo src.txt dst.txt
test_expected_warnings+=2

TestPhase_Run #################################################################
AconfCompileOutput

TestPhase_Check ###############################################################

TestDone ######################################################################
