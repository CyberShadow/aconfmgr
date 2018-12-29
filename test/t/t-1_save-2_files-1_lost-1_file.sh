#!/bin/bash
source ./lib.bash

# Test saving lost files.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 'Lost file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /lostfile.txt
EOF

diff -u "$config_dir"/files/lostfile.txt <(printf "Lost file contents")

TestDone ######################################################################
