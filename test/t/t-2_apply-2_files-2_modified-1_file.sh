#!/bin/bash
source ./lib.bash

# Test applying modified files.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddFile /testfile.txt 'Original file contents'
TestAddPackageFile test-package /testfile.txt 'Original file contents'
TestAddConfig 'echo "Modified file contents" > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
