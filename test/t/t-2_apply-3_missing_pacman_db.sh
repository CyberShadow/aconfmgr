#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

TestIntegrationOnly

# Test recovery from missing pacman databases.

TestPhase_Setup ###############################################################
TestCreatePackage test-package native
TestAddConfig AddPackage test-package
command sudo rm -rf /var/lib/pacman/sync

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog <<EOF
--sync --refresh --sysupgrade --noconfirm
--sync test-package
EOF

TestDone ######################################################################
