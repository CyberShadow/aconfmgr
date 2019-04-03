#!/bin/bash
source ./lib.bash

# Test installing packages.
TestNeedAUR
TestAURHelpers

TestPhase_Setup ###############################################################
TestAddPackageFile test-package-"$aur_helper" /testfile-"$aur_helper".txt 'File contents'
TestCreatePackage test-package-"$aur_helper" foreign
TestAddConfig AddPackage --foreign test-package-"$aur_helper"

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile-"$aur_helper".txt) <(printf 'File contents')

TestDone ######################################################################
