#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 300cb65847c4f8cd3b6517690d2af52502b3e3de
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
