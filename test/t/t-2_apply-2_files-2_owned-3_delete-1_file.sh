#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test deleting a package file.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddConfig SetFileProperty /testfile.txt deleted y

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/testfile.txt

TestDone ######################################################################
