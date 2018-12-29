#!/bin/bash
source ./lib.bash

# Test ignored files.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 'Lost file contents'
TestAddConfig IgnorePath /lostfile.txt

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
