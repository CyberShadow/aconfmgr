#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test building AUR packages when makepkg is configured
# to place the built packages in another directory.
TestNeedAUR

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo
TestCreatePackage test-package foreign

mkdir /tmp/pkgdest
command sudo tee -a /etc/makepkg.conf > /dev/null <<< 'PKGDEST=/tmp/pkgdest'

# shellcheck disable=SC2016
TestAddConfig 'echo bar >> "$(GetPackageOriginalFile test-package /testfile.txt)"'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u /testfile.txt /dev/stdin <<<foobar

TestDone ######################################################################
