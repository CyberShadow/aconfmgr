#!/bin/bash
source ./lib.bash

# Test saving stray files.

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /strayfile.txt
EOF

diff -u "$config_dir"/files/strayfile.txt <(printf "Stray file contents")

TestDone ######################################################################
