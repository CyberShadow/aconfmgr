#!/bin/bash
source ./lib.bash

# Test saving modified file properties.

TestPhase_Setup ###############################################################

TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /badfile.txt 'This is a bad file' 666 billy wheel
TestAddPackageFile test-package /badfile.txt 'This is a bad file'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
SetFileProperty /badfile.txt group wheel
SetFileProperty /badfile.txt mode 666
SetFileProperty /badfile.txt owner billy
EOF

TestDone ######################################################################
