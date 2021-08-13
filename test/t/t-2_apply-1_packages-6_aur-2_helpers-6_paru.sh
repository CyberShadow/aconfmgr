#!/bin/bash
source ./lib.bash

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 5291045d8708e67be627a728b1f379d447c5e1cc
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
