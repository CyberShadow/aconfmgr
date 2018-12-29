#!/bin/bash
source ./lib.bash

# Test configuration parsing warning due to relative paths.

TestMockOnly
TestPhase_Setup ###############################################################
TestWriteFile "$config_dir"/files/src.txt 'Test file contents'
TestAddConfig CopyFileTo src.txt dst.txt

TestPhase_Run #################################################################
AconfCompileOutput

TestPhase_Check ###############################################################
test $config_warnings -eq 2

TestDone ######################################################################
