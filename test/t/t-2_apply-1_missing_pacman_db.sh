#!/bin/bash
source ./lib.bash

TestIntegrationOnly

# Test recovery from missing pacman databases.

TestPhase_Setup ###############################################################
command sudo rm -rf /var/lib/pacman/sync
TestCreatePackage test-package native
TestAddConfig AddPackage test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--sync test-package
EOF

TestDone ######################################################################
