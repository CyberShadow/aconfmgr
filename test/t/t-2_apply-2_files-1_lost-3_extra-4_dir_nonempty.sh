#!/bin/bash
source ./lib.bash

# Test deleting extra directories containing some ignored paths.

TestPhase_Setup ###############################################################
TestAddDir /a/b/c
TestAddDir /a/testfile.txt
TestAddConfig IgnorePath '/a/testfile.txt'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/files/a/b/c
test ! -e "$test_data_dir"/files/a/b
test   -e "$test_data_dir"/files/a/testfile.txt

TestDone ######################################################################
