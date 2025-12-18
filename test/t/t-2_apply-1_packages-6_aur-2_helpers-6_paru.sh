#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 329be2113c590046cb29858c23d9b96a8d7bd586  # v2.1.0, alpm.rs 4.x, libalpm v15
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
