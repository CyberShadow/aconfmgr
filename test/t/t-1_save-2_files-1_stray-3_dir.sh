#!/usr/bin/env bash
source ./lib.bash

# Test saving empty directories.

TestPhase_Setup ###############################################################
TestAddDir /emptydir

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CreateDir /emptydir
EOF

TestDone ######################################################################
