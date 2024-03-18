#!/bin/bash
source ./lib.bash

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 2bfa586c9fbf08144257c1e5c013481d43760e1a
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
