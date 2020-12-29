#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 9b9926ce69e2f702b14bf5113f9705ca9f467d2e
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
