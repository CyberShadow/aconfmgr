#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test saving stray files inside a directory.
# This test verifies that aconfmgr is not emitting unnecessary CreateDir lines.

TestPhase_Setup ###############################################################
TestAddFile /dir/strayfile.txt 'Stray file contents'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<"EOF"
printf -- '%s' 'Stray file contents' > "$(CreateFile /dir/strayfile.txt)"
EOF


TestDone ######################################################################
