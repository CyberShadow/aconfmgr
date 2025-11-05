#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test --skip-config

TestPhase_Setup ###############################################################
AconfSave # Inspect system

# This configuration change won't be visible to aconfmgr with --skip-config
# shellcheck disable=SC2016
TestAddConfig 'echo File contents > $(CreateFile /file.txt)'

TestPhase_Run #################################################################
skip_config=y
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
EOF
test ! -e "$config_dir"/files/strayfile.txt

TestDone ######################################################################
