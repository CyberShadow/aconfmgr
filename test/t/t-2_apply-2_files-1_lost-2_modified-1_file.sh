#!/bin/bash
source ./lib.bash

# Test modifying a lost file.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /testfile.txt foo
TestAddConfig 'echo bar > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/files/testfile.txt /dev/stdin <<<bar

TestDone ######################################################################
