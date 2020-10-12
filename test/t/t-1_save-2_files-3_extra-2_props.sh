#!/bin/bash
source ./lib.bash

# Test removing extra file properties (specified in the configuration, but not the system).

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents'

TestAddConfig 'printf "Stray file contents" > $(CreateFile /strayfile.txt 777 billy wheel)'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
SetFileProperty /strayfile.txt group ''
SetFileProperty /strayfile.txt mode ''
SetFileProperty /strayfile.txt owner ''
EOF

TestDone ######################################################################
