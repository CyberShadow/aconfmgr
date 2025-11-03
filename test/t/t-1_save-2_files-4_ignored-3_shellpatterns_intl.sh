#!/usr/bin/env bash
source ./lib.bash

# Test ignored files (using shell patterns over international characters).

TestPhase_Setup ###############################################################
TestAddFile '/Meine Grüße.txt' 'Stray file contents'
TestAddFile '/Viele-Grüße.txt' 'Stray file contents'
TestAddFile '/Die Grüße.txt' 'Stray file contents'

TestAddConfig IgnorePath "'"'/Meine Grüße.txt'"'"
TestAddConfig IgnorePath "'"'/Viele-Gr*e.txt'"'"
TestAddConfig IgnorePath "'"'/D?e Gr*e.txt'"'"

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF

TestDone ######################################################################
