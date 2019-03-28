#!/bin/bash
# shellcheck disable=SC2031
source ./lib.bash
source ./lib-matrix-files.bash

# Regression tests for past matrix failures.
# The full matrix test is too slow to run as a normal part of the test suite;
# they can be run manually from the ./m-*.sh scripts.

TestPhase_Setup ###############################################################

tests=(
	01-2311-1321-1123
	01-2311-1321-1132
	00-2311-1322-1123
	00-1111-1311-1233
	00-1311-1222-1333
	00-0111-1122-1233
	01-0111-1122-1233
	00-1311-1111-1113
	00-1111-0122-0133
	01-2211-1322-1322
	01-0111-1222-1322
	00-2111-0122-1331
	00-2111-1311-2133
	00-2311-1221-0133
	10-1211-1222-0133
	01-1211-1221-1331
	# 00-0111-1222-2133
	00-2211-1322-0133
	00-2111-1312-1102
)
TestMatrixFileSetup "${tests[@]}"
unset tests

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
TestMatrixFileCheckApply

TestDone ######################################################################
