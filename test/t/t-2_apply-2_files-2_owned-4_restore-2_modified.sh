#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test restoring a modified package file.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddFile /testfile.txt bar

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt <(printf foo)

TestDone ######################################################################
