#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using pacaur.

TestNeedAUR
TestNeedPacaur
TestNeedAuracle
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
