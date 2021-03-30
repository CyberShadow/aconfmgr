#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 4dc2bbb9f9fbe18befb3f64a61d5edaa7039a45f
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
