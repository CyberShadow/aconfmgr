#!/usr/bin/env bash
source ./lib.bash

# Test saving stray files inside a directory.
# This test verifies that aconfmgr is not emitting unnecessary CreateDir lines.

TestPhase_Setup ###############################################################
TestAddFile /dir/strayfile.txt 'Stray file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /dir/strayfile.txt
EOF

diff -u "$config_dir"/files/dir/strayfile.txt <(printf "Stray file contents")

TestDone ######################################################################
