#!/bin/bash
source ./lib.bash

# Test that a file with all properties equal other than a different file size
# is detected as modified when using the skip_checksums property

TestPhase_Setup ###############################################################
skip_checksums=y

TestAddPackageFile test-package /badfile.txt 'Original file' 777 billy wheel
# NB: Packages files are always installed with timestamp 0,
# since they are generated using SOURCE_DATE_EPOCH=0 makepkg
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /badfile.txt 'Not original file' 777 billy wheel @0

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<"EOF"
printf '%s' 'Not original file' > "$(CreateFile /badfile.txt)"
EOF

TestDone ######################################################################
