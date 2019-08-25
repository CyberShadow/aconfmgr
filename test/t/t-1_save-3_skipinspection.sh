#!/bin/bash
source ./lib.bash

# Test --skip-inspection

TestPhase_Setup ###############################################################
AconfSave # Inspect system

# This system change won't be visible to aconfmgr with --skip-inspection
TestAddFile /lostfile.txt 'Lost file contents'

TestPhase_Run #################################################################
skip_inspection=y
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF
test ! -e "$config_dir"/files/lostfile.txt

TestDone ######################################################################
