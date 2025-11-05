#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test ignored files (simple path without shell patterns).

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents'
TestAddConfig IgnorePath /strayfile.txt

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
