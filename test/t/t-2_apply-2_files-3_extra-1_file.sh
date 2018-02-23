#!/bin/bash
source ./lib.bash

# Test deleting an extra file.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddFile /testfile.txt foo

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
! test -e "$test_data_dir"/files/testfile.txt

TestDone ######################################################################
