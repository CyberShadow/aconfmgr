#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test basic 'aconfmgr check' functionality.

TestPhase_Run #################################################################
AconfCheck

TestPhase_Check ###############################################################

TestDone ######################################################################
