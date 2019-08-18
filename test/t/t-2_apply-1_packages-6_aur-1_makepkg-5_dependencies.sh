#!/bin/bash
source ./lib.bash

# Test building AUR packages with dependencies.
TestNeedAUR
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 0edc474c5acf43635aed4899da1d100fe061d602 'source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")'

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
