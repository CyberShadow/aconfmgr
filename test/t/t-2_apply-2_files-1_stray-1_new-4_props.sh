#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test installing a file with non-default properties.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /extrafile.txt 600 billy wheel)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(stat --format=%a /extrafile.txt) <(echo 600)
diff -u <(stat --format=%U /extrafile.txt) <(echo billy)
diff -u <(stat --format=%G /extrafile.txt) <(echo wheel)

TestDone ######################################################################
