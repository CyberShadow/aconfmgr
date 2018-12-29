#!/bin/bash
source ./lib.bash

# Test installing a symbolic link.

TestPhase_Setup ###############################################################
TestAddConfig CreateLink /symlink target

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test -h "$test_fs_root"/symlink
diff -u <(readlink "$test_fs_root"/symlink) /dev/stdin <<<target

TestDone ######################################################################
