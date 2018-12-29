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
# diff -u "$test_data_dir"/files/testfile.txt /dev/stdin <<<bar
diff -u "$test_data_dir"/files/testfile.txt <(printf foo)

TestDone ######################################################################
