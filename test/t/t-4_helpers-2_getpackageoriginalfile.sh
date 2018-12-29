#!/bin/bash
source ./lib.bash

# Test GetPackageOriginalFile helper.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /testfile.txt baz
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackageFile test-package

TestAddConfig 'echo bar >> $(GetPackageOriginalFile test-package /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<foobar

TestDone ######################################################################
