#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru cb5e3ab7356e0d03c4688170c861ccc38c7246a7
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
