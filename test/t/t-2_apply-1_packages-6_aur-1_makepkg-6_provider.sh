#!/bin/bash
source ./lib.bash

# Test building AUR packages depending on a provided package.
TestNeedAUR

TestPhase_Setup ###############################################################

TestCreatePackage test-provider native 'provides=(test-service)'

TestAddPackageFile test-package /testfile.txt 'File contents'
TestCreatePackage test-package foreign 'depends=(test-service)'
TestAddConfig AddPackage --foreign test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
