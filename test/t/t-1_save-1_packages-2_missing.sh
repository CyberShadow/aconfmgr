#!/usr/bin/env bash
source ./lib.bash

# Test saving missing packages.

TestPhase_Setup ###############################################################
TestAddConfig AddPackage           test-native-package
TestAddConfig AddPackage --foreign test-foreign-package

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
RemovePackage test-native-package
RemovePackage --foreign test-foreign-package
EOF

TestDone ######################################################################
