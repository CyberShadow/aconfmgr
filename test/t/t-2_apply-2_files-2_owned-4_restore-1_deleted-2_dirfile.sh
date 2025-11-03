#!/usr/bin/env bash
source ./lib.bash

# Test restoring a deleted package file (in a subdirectory).

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /a/b/testfile.txt foo
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestDeleteFile /a/b/testfile.txt

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/a/b/testfile.txt <(printf foo)

TestDone ######################################################################
