#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 68659a24734580d64c9c5e0899d60431126c53c3
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
