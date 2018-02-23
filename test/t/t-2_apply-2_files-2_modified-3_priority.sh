#!/bin/bash
source ./lib.bash

# Test applying modified priority files.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddFile /etc/pacman.conf 'Original file contents'
TestAddPackageFile pacman /etc/pacman.conf 'Original file contents'
TestAddConfig 'echo "Modified file contents" > $(CreateFile /etc/pacman.conf)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /etc/pacman.conf) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
