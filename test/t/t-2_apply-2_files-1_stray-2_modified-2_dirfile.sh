#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test modifying a stray file (in a directory).

TestPhase_Setup ###############################################################
TestAddFile /dir/testfile.txt foo
TestAddConfig 'echo bar > $(CreateFile /dir/testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/dir/testfile.txt /dev/stdin <<<bar

TestDone ######################################################################
