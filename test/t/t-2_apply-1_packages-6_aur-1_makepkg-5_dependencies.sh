#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test building AUR packages with dependencies.
TestNeedAUR
TestNeedAuracle

TestPhase_Setup ###############################################################

TestCreatePackage native-dependency native
TestCreatePackage foreign-dependency foreign

TestAddPackageFile test-package /testfile.txt 'File contents'
TestCreatePackage test-package foreign 'depends=(native-dependency foreign-dependency)'
TestAddConfig AddPackage --foreign test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
