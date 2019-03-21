#!/bin/bash
source ./lib.bash

# Test basic package list saving.

TestPhase_Setup ###############################################################
TestAddPackage test-native-explicit-package    native  explicit
TestAddPackage test-native-dependency-package  native  dependency
TestAddPackage test-foreign-explicit-package   foreign explicit
TestAddPackage test-foreign-dependency-package foreign dependency

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
AddPackage --foreign test-foreign-explicit-package # Dummy aconfmgr test suite package
AddPackage test-native-explicit-package # Dummy aconfmgr test suite package
EOF

TestDone ######################################################################
