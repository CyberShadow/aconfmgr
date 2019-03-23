#!/bin/bash
source ./lib.bash

# Test modifying a file that's not on the filesystem.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package native

# shellcheck disable=SC2016
TestAddConfig 'echo bar >> $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################

diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<bar

TestDone ######################################################################
