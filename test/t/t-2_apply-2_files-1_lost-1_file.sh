#!/bin/bash
source ./lib.bash

# Test installing a file.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddConfig 'echo foo > $(CreateFile /extrafile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/files/extrafile.txt /dev/stdin <<<foo

TestDone ######################################################################
