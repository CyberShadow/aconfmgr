#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru c731ae9e6229a6f6a3f37719d2d8ba8053e7683c
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
