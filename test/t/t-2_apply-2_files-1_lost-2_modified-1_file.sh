#!/bin/bash
source ./lib.bash

# Test modifying a lost file.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt foo
TestAddConfig 'echo bar > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<bar

TestDone ######################################################################
