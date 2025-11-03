#!/usr/bin/env bash
source ./lib.bash

# Test RemoveFile helper.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /testfile.txt)'
TestAddConfig RemoveFile /testfile.txt

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/testfile.txt

TestDone ######################################################################
