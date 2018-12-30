#!/bin/bash
source ./lib.bash

# Test installing a package.

TestMockOnly
TestPhase_Setup ###############################################################
TestCreatePackage test-package native
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/pacman-actions.txt /dev/stdin <<EOF
install test-package
EOF

TestDone ######################################################################
