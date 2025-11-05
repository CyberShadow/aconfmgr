#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test successful 'aconfmgr check' invocation.

TestPhase_Setup ###############################################################
TestAddConfig CopyFile /testfile.txt
TestWriteFile "$config_dir"/files/testfile.txt 'Test file contents'

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################

TestDone ######################################################################
