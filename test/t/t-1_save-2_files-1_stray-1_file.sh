#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test saving stray files.

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<"EOF"
printf -- '%s' 'Stray file contents' > "$(CreateFile /strayfile.txt)"
EOF

TestDone ######################################################################
