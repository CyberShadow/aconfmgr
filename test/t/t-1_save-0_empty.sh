#!/bin/bash
source ./lib.bash

# Test basic 'aconfmgr save' functionality.

TestMockOnly
TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
