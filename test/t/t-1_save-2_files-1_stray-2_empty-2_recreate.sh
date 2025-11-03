#!/usr/bin/env bash
source ./lib.bash

# Test that saving correctly emits a RemoveFile before CreateFile, to
# avoid creating a configuration which will emit a warning when
# sourced.

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt ''
TestAddConfig 'echo foo > $(CreateFile /strayfile.txt)'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
RemoveFile /strayfile.txt
CreateFile /strayfile.txt > /dev/null
EOF

test ! -e "$config_dir"/files/strayfile.txt # should not exist

TestDone ######################################################################
