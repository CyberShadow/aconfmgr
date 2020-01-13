#!/bin/bash
source ./lib.bash

# Test that any AUR helpers specified in the configuration are built first, then used.
TestNeedAUR
TestNeedPacaur
TestNeedAuracle

TestPhase_Setup ###############################################################

TestAddPackageFile a-test-package /testfile.txt 'File contents'
TestCreatePackage a-test-package foreign

TestAddConfig AddPackage --foreign pacaur
TestAddConfig AddPackage --foreign a-test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

# Check that it was built by pacaur
test -f ~/.cache/pacaur/a-test-package/a-test-package-1.0-1-x86_64.pkg.tar.xz

TestDone ######################################################################
