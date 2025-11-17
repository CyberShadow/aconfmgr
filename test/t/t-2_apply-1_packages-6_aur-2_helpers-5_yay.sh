#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay e885796b3585256503bf9429c25190ea5fefd2c2  # v12.4.2, libalpm v15 compatible
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
