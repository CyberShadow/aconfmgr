#!/bin/bash
source ./lib.bash

# Test for ignored packages.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddPackage foo native explicit
TestAddConfig IgnorePackage foo
TestAddConfig IgnorePackage bar

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
test ! -e "$test_data_dir"/pacman-actions.txt

TestDone ######################################################################
