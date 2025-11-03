#!/usr/bin/env bash
source ./lib.bash

# Test that a file with all properties equal is _not_ detected as modified when
# using the skip_checksums property, even though the contents are different
# This exercises the unusual worst-case where somehow a file's content changes
# without updating any property, where, we are going to fail to detect the change
# This should not happen outside unusual scenarios (e.g. filesystem corruption,
# intentional manipulation, badly behaved programs manipulating mtime)

TestPhase_Setup ###############################################################
skip_checksums=y

TestAddPackageFile test-package /badfile.txt 'Original file' 777 billy wheel
# NB: Packages files are always installed with timestamp 0,
# since they are generated using SOURCE_DATE_EPOCH=0 makepkg
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package

TestAddFile /badfile.txt 'Another file!' 777 billy wheel @0

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
EOF

TestDone ######################################################################
