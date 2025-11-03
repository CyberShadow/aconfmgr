#!/usr/bin/env bash
source ./lib.bash

# Test that the GetPackageOriginalFile helper emits a warning when
# overwriting a file.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt baz
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package native

TestAddConfig 'echo spam >> "$(GetPackageOriginalFile test-package /testfile.txt)"'
TestAddConfig 'echo eggs >> "$(GetPackageOriginalFile test-package /testfile.txt)"'
test_expected_warnings+=1

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<$'fooeggs'

TestDone ######################################################################
