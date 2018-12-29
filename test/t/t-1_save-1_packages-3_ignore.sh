#!/bin/bash
source ./lib.bash

# Test for ignored packages.

TestMockOnly
TestPhase_Setup ###############################################################
TestAddPackage foo native explicit
TestAddConfig IgnorePackage foo
TestAddConfig IgnorePackage bar

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig < /dev/null

TestDone ######################################################################
