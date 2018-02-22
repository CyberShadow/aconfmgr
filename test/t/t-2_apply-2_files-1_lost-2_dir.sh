#!/bin/bash
source ./lib.bash

# Test installing a directory.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddConfig 'CreateDir /emptydir'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test -d "$test_data_dir"/files/emptydir

TestDone ######################################################################
