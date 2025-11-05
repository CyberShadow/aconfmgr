#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test deleting extra directories containing some ignored paths.

TestPhase_Setup ###############################################################
TestAddDir /a/b/c
TestAddDir /a/testfile.txt
TestAddConfig IgnorePath '/a/testfile.txt'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/a/b/c
test ! -e "$test_fs_root"/a/b
test   -e "$test_fs_root"/a/testfile.txt

TestDone ######################################################################
