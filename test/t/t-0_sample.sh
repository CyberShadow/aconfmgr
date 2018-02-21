#!/bin/bash
source ./lib.bash

# Example test case script.

# aconfmgr test cases can have three phases,
# all optional: setup, run, and check.

# Setup phase (configure the environment).
TestPhase_Setup

a=2
b=2

# Run phase (execute the relevant parts of aconfmgr being tested).
TestPhase_Run

c=$((a+b))

# Check phase (verify that the resulting state is as expected).
TestPhase_Check

test $c -eq 4

# Tests must end with an invocation of TestDone.
TestDone
