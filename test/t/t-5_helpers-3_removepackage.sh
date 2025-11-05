#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test RemovePackage helper.

TestPhase_Setup ###############################################################
TestAddConfig AddPackage foo
TestAddConfig RemovePackage foo

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/pacman-actions.txt

TestDone ######################################################################
