#!/usr/bin/env bash
source ./lib.bash

# Test AUR functionality using pacaur.

TestNeedAUR
TestNeedPacaur
TestNeedAuracle
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
