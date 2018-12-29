#!/bin/bash
source ./lib.bash

# Test saving symbolic links.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddLink /symlink target

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CreateLink /symlink target
EOF

TestDone ######################################################################
