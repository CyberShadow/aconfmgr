#!/bin/bash
source ./lib.bash

# Test installing a package.

TestPhase_Setup ###############################################################
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/installed-packages.txt /dev/stdin <<EOF
test-package
EOF

TestDone ######################################################################
