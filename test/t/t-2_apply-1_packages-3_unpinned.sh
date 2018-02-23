#!/bin/bash
source ./lib.bash

# Test pinning a package.

TestPhase_Setup ###############################################################
TestAddPackage test-package native dependency
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/pacman-actions.txt /dev/stdin <<EOF
pin test-package
EOF

TestDone ######################################################################
