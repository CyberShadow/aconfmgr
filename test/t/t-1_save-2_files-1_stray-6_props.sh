#!/bin/bash
source ./lib.bash

# Test saving stray files with unusual properties.

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents' 777 billy wheel

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<"EOF"
printf -- '%s' 'Stray file contents' > "$(CreateFile /strayfile.txt 777 billy wheel)"
EOF

TestDone ######################################################################
