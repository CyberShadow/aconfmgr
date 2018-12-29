#!/bin/bash
source ./lib.bash

# Test deleting extra directories.

TestPhase_Setup ###############################################################
TestAddDir /a/b/c

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_fs_root"/a

TestDone ######################################################################
