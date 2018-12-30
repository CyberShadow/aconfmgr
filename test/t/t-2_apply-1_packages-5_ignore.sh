#!/bin/bash
source ./lib.bash

# Test for ignored packages.

TestPhase_Setup ###############################################################
TestAddPackage foo native explicit
TestAddConfig IgnorePackage foo
TestAddConfig IgnorePackage bar

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestExpectPacManLog < /dev/null

TestDone ######################################################################
