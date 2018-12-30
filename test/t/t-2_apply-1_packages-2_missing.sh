#!/bin/bash
source ./lib.bash

# Test unpinning a package.

TestPhase_Setup ###############################################################
TestAddPackage test-package native explicit

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--database --asdeps test-package
--remove test-package
EOF

TestDone ######################################################################
