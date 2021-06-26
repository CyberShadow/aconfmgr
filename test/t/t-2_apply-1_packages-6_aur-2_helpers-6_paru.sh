#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 5f55b1c8060be1a5ae5ea9895f440d25fecd91b6
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
