#!/bin/bash
# shellcheck disable=SC2031
source ./lib.bash
source ./lib-matrix-packages.bash

# Matrix roundtrip test for packages.

TestPhase_Setup ###############################################################

TestMatrixPackageSetup

TestPhase_Run #################################################################
AconfSave
AconfApply

TestPhase_Check ###############################################################
TestMatrixPackageCheckRoundtrip

TestDone ######################################################################
