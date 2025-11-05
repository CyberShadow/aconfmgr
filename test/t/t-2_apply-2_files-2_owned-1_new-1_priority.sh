#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test applying new priority files.

TestPhase_Setup ###############################################################
priority_files+=(/dir/file.txt)
TestAddConfig 'echo "Priority file contents" > $(CreateFile /dir/file.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /dir/file.txt) /dev/stdin <<<'Priority file contents'

TestDone ######################################################################
