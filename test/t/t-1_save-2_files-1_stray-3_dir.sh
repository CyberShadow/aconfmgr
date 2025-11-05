#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

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
