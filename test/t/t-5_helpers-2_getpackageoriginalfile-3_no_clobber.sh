#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test the --no-clobber option for the GetPackageOriginalFile helper.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt baz
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package native

TestAddConfig 'echo spam > "$(GetPackageOriginalFile --no-clobber test-package /testfile.txt)"'
TestAddConfig 'echo eggs >> "$(GetPackageOriginalFile --no-clobber test-package /testfile.txt)"'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<$'spam\neggs'

TestDone ######################################################################
