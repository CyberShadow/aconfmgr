#!/bin/bash
source ./lib.bash

# Test clearing file properties.

TestPhase_Setup ###############################################################
TestAddFile /testfile.txt foo 666 billy wheel
TestAddConfig 'printf foo > $(CreateFile /testfile.txt)'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(stat --format=%a /testfile.txt) <(echo 644)
diff -u <(stat --format=%U /testfile.txt) <(echo root)
diff -u <(stat --format=%G /testfile.txt) <(echo root)

TestDone ######################################################################
