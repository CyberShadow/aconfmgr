#!/bin/bash
source ./lib.bash

# Test applying modified priority files.

TestPhase_Setup ###############################################################
TestAddFile /dir/file.txt 'Original file contents'
TestAddPackageFile pacman /dir/file.txt 'Original file contents'
TestAddConfig 'echo "Modified file contents" > $(CreateFile /dir/file.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /dir/file.txt) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
