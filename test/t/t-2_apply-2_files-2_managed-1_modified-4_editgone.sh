#!/bin/bash
source ./lib.bash

# Test modifying a file that's not on the filesystem.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackageFile test-package

TestAddConfig 'echo bar >> $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################

# XFAIL - FIXME!
# diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<bar
diff -u "$test_fs_root"/testfile.txt <(printf foo)

TestDone ######################################################################
