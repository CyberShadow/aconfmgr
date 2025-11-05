#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AconfNeedProgram helper for native packages.
TestNeedAUR

TestPhase_Setup ###############################################################
TestAddPackageFile test-native-package /usr/bin/test-native-program $'#!/bin/sh\necho "Test program!"' 755
TestAddPackageFile test-foreign-package /usr/bin/test-foreign-program $'#!/bin/sh\necho "Test program!"' 755
TestCreatePackage test-native-package native
TestCreatePackage test-foreign-package foreign

TestPhase_Run #################################################################
AconfNeedProgram test-native-program test-native-package n
AconfNeedProgram test-foreign-program test-foreign-package y

TestPhase_Check ###############################################################
/usr/bin/test-native-program
/usr/bin/test-foreign-program

TestDone ######################################################################
