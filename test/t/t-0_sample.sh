#!/usr/bin/env bash
source ./lib.bash

# Example test case script.

# aconfmgr test cases can have three phases,
# all optional: setup, run, and check.

TestPhase_Setup ###############################################################

# Setup phase (configure the environment).
a=2
b=2

TestPhase_Run #################################################################

# Run phase (execute the relevant parts of aconfmgr being tested).
c=$((a+b))

TestPhase_Check ###############################################################

# Check phase (verify that the resulting state is as expected).
test $c -eq 4

# Tell the test suite we intentionally declared some globals.
test_globals_whitelist+=(a b c)

# Tests must end with an invocation of TestDone.
TestDone ######################################################################
