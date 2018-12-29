#!/bin/bash
source ./lib.bash

# Test deleting extra directories.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddDir /a/b/c

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/files/a

TestDone ######################################################################
