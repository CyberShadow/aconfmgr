#!/usr/bin/env bash
source ./lib.bash

# Test applying modified priority files.

TestPhase_Setup ###############################################################
priority_files+=(/dir/file.txt)
TestAddPackageFile test-package /dir/file.txt 'Original file contents'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddConfig 'echo "Modified file contents" > $(CreateFile /dir/file.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /dir/file.txt) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
