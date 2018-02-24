#!/bin/bash
source ./lib.bash

# Test RemoveFile helper.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /testfile.txt)'
TestAddConfig RemoveFile /testfile.txt

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/files/testfile.txt

TestDone ######################################################################
