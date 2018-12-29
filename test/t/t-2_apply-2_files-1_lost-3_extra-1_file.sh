#!/bin/bash
source ./lib.bash

# Test deleting an extra file.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt foo

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/testfile.txt

TestDone ######################################################################
