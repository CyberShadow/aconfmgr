#!/usr/bin/env bash
source ./lib.bash

# Ensure AconfNeedPackageFile etc. work when the pacman package
# directory is only readable via sudo.

TestIntegrationOnly

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package native

TestAddConfig 'echo bar >> "$(GetPackageOriginalFile test-package /testfile.txt)"'

command sudo chmod 700 /var/cache/pacman/pkg

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u "$test_fs_root"/testfile.txt /dev/stdin <<<foobar

TestDone ######################################################################
