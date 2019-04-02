#!/bin/bash
source ./lib.bash

# Test basic AUR functionality.
TestNeedAUR

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt 'File contents'
TestCreatePackage test-package foreign
TestAddConfig AddPackage --foreign test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
