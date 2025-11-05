#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test building AUR packages when aconfmgr was launched as root.
TestNeedRoot
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
