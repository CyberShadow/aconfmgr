#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test the destination path parameter of the GetPackageOriginalFile helper.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

# shellcheck disable=SC2016
TestAddConfig 'echo bar >> "$(GetPackageOriginalFile test-package /testfile.txt /dir/copy.txt)"'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/dir/copy.txt /dev/stdin <<<foobar
# The file at the original location is unaffected.
diff -u "$test_fs_root"/testfile.txt <(printf foo)

TestDone ######################################################################
