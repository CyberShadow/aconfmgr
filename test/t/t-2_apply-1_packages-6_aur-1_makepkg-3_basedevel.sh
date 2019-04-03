#!/bin/bash
source ./lib.bash

# Test installing base-devel if needed.
TestNeedAUR

TestPhase_Setup ###############################################################

sudo pacman -R --noconfirm automake
TestAddConfig RemovePackage automake
TestAddConfig IgnorePackage automake

TestAddPackageFile test-package /testfile.txt 'File contents'
TestCreatePackage test-package foreign
TestAddConfig AddPackage --foreign test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
