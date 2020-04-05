#!/bin/bash
source ./lib.bash

# Test ignored files (using shell patterns over international characters).

TestPhase_Setup ###############################################################
TestAddFile '/Meine Grüße.txt' 'Lost file contents'
TestAddFile '/Viele-Grüße.txt' 'Lost file contents'
TestAddFile '/Die Grüße.txt' 'Lost file contents'

TestAddConfig IgnorePath "'"'/Meine Grüße.txt'"'"
TestAddConfig IgnorePath "'"'/Viele-Gr*e.txt'"'"
TestAddConfig IgnorePath "'"'/D?e Gr*e.txt'"'"

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
