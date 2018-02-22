#!/bin/bash
source ./lib.bash

# Test saving extra files (lost files in the configuration, but not the system).

TestPhase_Setup ###############################################################
TestAddConfig 'echo foo > $(CreateFile /extrafile.txt)'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
RemoveFile /extrafile.txt
EOF

TestDone ######################################################################
