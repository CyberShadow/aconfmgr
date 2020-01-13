#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedPacaur
TestNeedAuracle
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
