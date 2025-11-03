#!/usr/bin/env bash
source ./lib.bash

# Test installing base-devel if needed.
TestNeedAUR

TestPhase_Setup ###############################################################

command sudo pacman -R --noconfirm base-devel
TestAddConfig RemovePackage base-devel
TestAddConfig IgnorePackage base-devel

command sudo pacman -S --noconfirm sudo
TestAddConfig AddPackage sudo
TestAddConfig IgnorePackage sudo

TestAddPackageFile test-package /testfile.txt 'File contents'
TestCreatePackage test-package foreign
TestAddConfig AddPackage --foreign test-package

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
