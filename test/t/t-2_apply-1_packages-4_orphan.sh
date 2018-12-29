#!/bin/bash
source ./lib.bash

# Test removing an orphan package.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddPackage test-explicit-package native explicit
TestAddPackage test-dependency-package native dependency
TestAddPackage test-orphan-package native orphan
TestAddConfig AddPackage test-explicit-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_data_dir"/pacman-actions.txt /dev/stdin <<EOF
remove test-orphan-package
EOF

TestDone ######################################################################
