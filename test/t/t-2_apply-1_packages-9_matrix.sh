#!/bin/bash
# shellcheck disable=SC2031
source ./lib.bash
source ./lib-matrix-packages.bash

TestPhase_Setup ###############################################################

TestMatrixPackageSetup

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestMatrixPackageCheckApply

TestDone ######################################################################
