#!/bin/bash
source ./lib.bash

# Test restoring a modified package file.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackageFile test-package
TestAddFile /testfile.txt bar

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/files/testfile.txt <(printf foo)

TestDone ######################################################################
