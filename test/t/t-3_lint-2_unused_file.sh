#!/bin/bash
source ./lib.bash

# Test successful 'aconfmgr check' invocation.

TestPhase_Setup ###############################################################
TestWriteFile "$config_dir"/files/testfile.txt 'Test file contents'

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################
test $config_warnings -eq 1

TestDone ######################################################################
