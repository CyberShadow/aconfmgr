#!/usr/bin/env bash
source ./lib.bash

# Test AddPackageGroup helper.

TestPhase_Setup ###############################################################
TestCreatePackage test-package native groups+=testgroup
TestAddConfig AddPackageGroup testgroup

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--sync test-package
EOF

TestDone ######################################################################
