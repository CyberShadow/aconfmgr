#!/bin/bash
source ./lib.bash

# Test saving empty directories.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddDir /emptydir

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CreateDir /emptydir
EOF

TestDone ######################################################################
