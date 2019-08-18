#!/bin/bash
source ./lib.bash

# Test that any AUR helpers specified in the configuration are built first, then used.
TestNeedAUR
TestNeedAURPackage pacaur da18900a6fe888654867748fa976f8ae0ab96334
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 0edc474c5acf43635aed4899da1d100fe061d602 'source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")'

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
