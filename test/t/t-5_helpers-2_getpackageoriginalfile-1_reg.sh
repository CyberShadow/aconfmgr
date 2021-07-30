#!/bin/bash
source ./lib.bash

# Test GetPackageOriginalFile helper.

TestPhase_Setup ###############################################################
TestAddFile /testfile1.txt baz
TestAddPackageFile test-package /testfile1.txt foo
TestAddFile /testfile2.txt baz
TestAddPackageFile test-package /testfile2.txt foo
TestCreatePackage test-package native

TestAddConfig 'echo spam >> "$(GetPackageOriginalFile test-package /testfile1.txt)"'
TestAddConfig 'echo bar >> "$(GetPackageOriginalFile test-package /testfile1.txt)"'

TestAddConfig 'echo spam > "$(GetPackageOriginalFile --no-clobber test-package /testfile2.txt)"'
TestAddConfig 'echo eggs >> "$(GetPackageOriginalFile --no-clobber test-package /testfile2.txt)"'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile1.txt /dev/stdin <<<foobar
diff -u "$test_fs_root"/testfile2.txt /dev/stdin <<<$'spam\neggs'

TestDone ######################################################################
