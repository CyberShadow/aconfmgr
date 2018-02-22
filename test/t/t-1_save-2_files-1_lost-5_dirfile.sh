#!/bin/bash
source ./lib.bash

# Test saving lost files inside a directory.
# This test verifies that aconfmgr is not emitting unnecessary CreateDir lines.

TestPhase_Setup ###############################################################
TestAddFile /dir/lostfile.txt 'Lost file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /dir/lostfile.txt
EOF

diff -u "$config_dir"/files/dir/lostfile.txt <(printf "Lost file contents")

TestDone ######################################################################
