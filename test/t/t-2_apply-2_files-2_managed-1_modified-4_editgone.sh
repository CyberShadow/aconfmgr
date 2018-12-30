#!/bin/bash
source ./lib.bash

# Test modifying a file that's not on the filesystem.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package native

TestAddConfig 'echo bar >> $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################

if ((${ACONFMGR_INTEGRATION:-0}))
then
	diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<bar
else
	# XFAIL (test suite bug) - FIXME!
	diff -u "$test_fs_root"/testfile.txt <(printf foo)
fi

TestDone ######################################################################
