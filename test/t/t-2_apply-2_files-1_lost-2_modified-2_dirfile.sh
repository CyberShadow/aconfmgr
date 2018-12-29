#!/bin/bash
source ./lib.bash

# Test modifying a lost file (in a directory).

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /dir/testfile.txt foo
TestAddConfig 'echo bar > $(CreateFile /dir/testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/files/dir/testfile.txt /dev/stdin <<<bar

TestDone ######################################################################
