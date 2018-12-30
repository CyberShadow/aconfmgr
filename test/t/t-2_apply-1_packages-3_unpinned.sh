#!/bin/bash
source ./lib.bash

# Test pinning a package.

TestPhase_Setup ###############################################################
TestAddPackage test-package native orphan
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--database --asexplicit test-package
EOF

TestDone ######################################################################
