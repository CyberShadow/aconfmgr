#!/usr/bin/env bash
source ./lib.bash

# Test that "save" generates a correct configuration when it needs to record
# deleting a non-empty directory.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /dir/file.txt)'

TestPhase_Run #################################################################
AconfSave
AconfApply

TestPhase_Check ###############################################################

TestDone ######################################################################
