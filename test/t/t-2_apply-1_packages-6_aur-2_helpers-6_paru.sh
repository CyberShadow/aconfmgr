#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 9f00c1bad581ba6a3e96158dfbbabd693a5ee179
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
