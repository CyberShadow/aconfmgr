#!/bin/bash
source ./lib.bash

# Test successful 'aconfmgr check' invocation.

TestPhase_Setup ###############################################################
TestAddConfig CopyFile /testfile.txt
TestWriteFile "$config_dir"/files/testfile.txt 'Test file contents'

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################
test $config_warnings -eq 0

TestDone ######################################################################
