#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test saving modified file properties.

TestPhase_Setup ###############################################################

TestAddPackageFile test-package /badfile.txt 'This is a bad file'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

#TestDeleteFile /badfile.txt
TestAddFile /badfile.txt 'This is a bad file' 666 billy wheel

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
SetFileProperty /badfile.txt group wheel
SetFileProperty /badfile.txt mode 666
SetFileProperty /badfile.txt owner billy
EOF

TestDone ######################################################################
