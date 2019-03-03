#!/bin/bash
source ./lib.bash

# Test RemoveFile helper.

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /dir/file.txt)'

TestPhase_Run #################################################################
AconfSave
AconfApply

TestPhase_Check ###############################################################

TestDone ######################################################################
