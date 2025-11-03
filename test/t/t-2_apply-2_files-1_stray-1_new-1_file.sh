#!/usr/bin/env bash
source ./lib.bash

# Test installing a file.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /extrafile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/extrafile.txt /dev/stdin <<<foo

TestDone ######################################################################
