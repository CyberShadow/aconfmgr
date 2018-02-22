#!/bin/bash
source ./lib.bash

# Test saving lost files with unusual properties.

TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 'Lost file contents' 777 billy wheel

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /lostfile.txt 777 billy wheel
EOF

diff -u "$config_dir"/files/lostfile.txt <(printf "Lost file contents")

TestDone ######################################################################
