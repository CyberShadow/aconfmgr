#!/bin/bash
source ./lib.bash

# Test saving empty files.

TestPhase_Setup ###############################################################
TestAddFile /emptyfile.txt 644 root root ''

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CreateFile /emptyfile.txt > /dev/null
EOF

! test -e "$config_dir"/files/emptyfile.txt # should not exist

TestDone ######################################################################
