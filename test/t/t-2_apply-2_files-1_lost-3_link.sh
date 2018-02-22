#!/bin/bash
source ./lib.bash

# Test installing a symbolic link.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddConfig CreateLink /symlink target

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test -h "$test_data_dir"/files/symlink
diff -u <(readlink "$test_data_dir"/files/symlink) /dev/stdin <<<target

TestDone ######################################################################
