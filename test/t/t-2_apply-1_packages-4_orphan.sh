#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test removing an orphan package.

TestPhase_Setup ###############################################################
TestAddPackage test-explicit-package native explicit
TestAddPackage test-dependency-package native dependency
TestAddPackage test-orphan-package native orphan
TestAddConfig AddPackage test-explicit-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--remove test-orphan-package
EOF

TestDone ######################################################################
