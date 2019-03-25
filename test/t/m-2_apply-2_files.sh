#!/bin/bash
# shellcheck disable=SC2031
source ./lib.bash
source ./lib-matrix-files.bash

# Full matrix test for files.

TestPhase_Setup ###############################################################
TestMatrixFileSetup

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestMatrixFileCheckApply

TestDone ######################################################################
