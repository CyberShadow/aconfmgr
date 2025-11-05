#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using aurman.

TestNeedAUR
TestNeedAURPackage aurman 4333dfe564874fc25b74da7891a8499003078c99
AconfMakePkg aurman
TestAddConfig AddPackage --foreign aurman
TestAURHelper aurman "${XDG_CACHE_HOME:-$HOME/.cache}/aurman" false
TestDone
