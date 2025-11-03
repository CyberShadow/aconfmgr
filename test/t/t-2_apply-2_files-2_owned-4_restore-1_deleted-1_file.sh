#!/usr/bin/env bash
source ./lib.bash

# Test restoring a deleted package file.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestDeleteFile /testfile

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt <(printf foo)

TestDone ######################################################################
