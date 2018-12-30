#!/bin/bash
source ./lib.bash

# Test installing a package.

TestPhase_Setup ###############################################################
TestCreatePackage test-package native
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--sync test-package
EOF

TestDone ######################################################################
