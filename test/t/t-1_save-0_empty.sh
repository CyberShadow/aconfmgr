#!/bin/bash
source ./lib.bash

# Test basic 'aconfmgr save' functionality.

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
