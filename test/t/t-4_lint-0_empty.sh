#!/bin/bash
source ./lib.bash

# Test basic 'aconfmgr check' functionality.

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################
test $config_warnings -eq 0

TestDone ######################################################################
