#!/bin/bash
source ./lib.bash

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 1671c778dfeab04b64686baf782c5baa2d96b2ec
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
