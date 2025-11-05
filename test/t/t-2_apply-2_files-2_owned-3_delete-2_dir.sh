#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test deleting some package directories.

TestPhase_Setup ###############################################################
TestAddPackageDir test-package /a/b/c
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddConfig SetFileProperty /a deleted y
TestAddConfig SetFileProperty /a/b deleted y
TestAddConfig SetFileProperty /a/b/c deleted y

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/a

TestDone ######################################################################
