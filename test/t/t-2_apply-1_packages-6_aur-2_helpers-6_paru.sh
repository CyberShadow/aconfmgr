#!/bin/bash
source ./lib.bash

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 7008763e43b8f950394acf736abd5dc0179d3ff1
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
