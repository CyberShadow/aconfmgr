#!/bin/bash
source ./lib.bash

# Test building AUR packages with dependencies.
TestNeedAUR
TestNeedAURPackage cower b81f1903b442d0e631a2958801e36955118ccbc0

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
