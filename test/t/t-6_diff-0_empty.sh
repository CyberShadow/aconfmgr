#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test basic 'aconfmgr diff' functionality.

TestPhase_Run #################################################################
TestDiff 0 /

TestPhase_Check ###############################################################

TestDone ######################################################################
