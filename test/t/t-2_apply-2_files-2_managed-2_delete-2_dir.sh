#!/bin/bash
source ./lib.bash

# Test deleting some package directories.

TestPhase_Setup ###############################################################
TestAddDir /a/b/c
TestAddPackageDir test-package /a/b/c
TestAddConfig SetFileProperty /a deleted y
TestAddConfig SetFileProperty /a/b deleted y
TestAddConfig SetFileProperty /a/b/c deleted y

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/files/a

TestDone ######################################################################
