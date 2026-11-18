#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru f8bb12fcd306aef6a6a8f8790d63e729a76849c9  # v2.2.1, requires pacman >= 7.1
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
