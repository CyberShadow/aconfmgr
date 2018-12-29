#!/bin/bash
source ./lib.bash

# Test deleting a package file.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /testfile.txt foo
TestAddPackageFile test-package /testfile.txt foo
TestAddConfig SetFileProperty /testfile.txt deleted y

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/files/testfile.txt

TestDone ######################################################################
