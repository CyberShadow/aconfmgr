#!/bin/bash
source ./lib.bash

# Test saving lost files.

TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 644 root root "Lost file contents"

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /lostfile.txt
EOF

TestDone ######################################################################
