#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test saving empty files.

TestPhase_Setup ###############################################################
TestAddFile /emptyfile.txt ''

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CreateFile /emptyfile.txt > /dev/null
EOF

test ! -e "$config_dir"/files/emptyfile.txt # should not exist

TestDone ######################################################################
