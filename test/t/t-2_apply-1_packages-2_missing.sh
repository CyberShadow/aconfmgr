#!/bin/bash
source ./lib.bash

# Test unpinning a package.

TestPhase_Setup ###############################################################
prompt_mode=never
TestAddPackage test-package native explicit

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/pacman-actions.txt /dev/stdin <<EOF
unpin test-package
EOF

TestDone ######################################################################
