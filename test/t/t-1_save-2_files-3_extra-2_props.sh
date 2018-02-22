#!/bin/bash
source ./lib.bash

# Test removing extra file properties (specified in the configuration, but not the system).

TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 'Lost file contents'

TestAddConfig 'printf "Lost file contents" > $(CreateFile /lostfile.txt 777 billy wheel)'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
SetFileProperty /lostfile.txt group ''
SetFileProperty /lostfile.txt mode ''
SetFileProperty /lostfile.txt owner ''
EOF

TestDone ######################################################################
