#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 28792e529d3ae608c2b7d57e0e0cece85bdd6f57
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
