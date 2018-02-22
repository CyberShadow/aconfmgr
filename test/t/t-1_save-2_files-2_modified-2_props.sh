#!/bin/bash
source ./lib.bash

# Test saving modified file properties.

TestPhase_Setup ###############################################################

TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /badfile.txt 'This is a bad file' 666 lucifer hell
TestAddModifiedFile /badfile.txt test-package UID root
TestAddModifiedFile /badfile.txt test-package GID root
TestAddModifiedFile /badfile.txt test-package permission 644

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
SetFileProperty /badfile.txt group hell
SetFileProperty /badfile.txt mode 666
SetFileProperty /badfile.txt owner lucifer
EOF

TestDone ######################################################################
