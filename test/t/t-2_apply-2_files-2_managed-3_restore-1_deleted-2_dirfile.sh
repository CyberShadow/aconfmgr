#!/bin/bash
source ./lib.bash

# Test restoring a deleted package file (in a subdirectory).

TestMockOnly
TestPhase_Setup ###############################################################
TestAddPackageFile test-package /a/b/testfile.txt foo
TestCreatePackageFile test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/a/b/testfile.txt <(printf foo)

TestDone ######################################################################
