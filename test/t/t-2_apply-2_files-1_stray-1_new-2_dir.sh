#!/bin/bash
source ./lib.bash

# Test installing a directory.

TestPhase_Setup ###############################################################
TestAddConfig CreateDir /emptydir

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test -d "$test_fs_root"/emptydir

TestDone ######################################################################
