#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test that modifying the contents of a package's file
# preserves the properties that the package gave it.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /testfile.txt foo 440 billy wheel
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
# shellcheck disable=SC2016
TestAddConfig 'echo bar >> "$(GetPackageOriginalFile test-package /testfile.txt)"'

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(sudo cat /testfile.txt) /dev/stdin <<<foobar
diff -u <(stat --format=%a /testfile.txt) <(echo 440)
diff -u <(stat --format=%U /testfile.txt) <(echo billy)
diff -u <(stat --format=%G /testfile.txt) <(echo wheel)

TestDone ######################################################################
