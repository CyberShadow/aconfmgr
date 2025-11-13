#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay 59714d8ae3dc1e5790228c1faeef8283b0c0101f  # v12.4.2, libalpm v15 compatible
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
