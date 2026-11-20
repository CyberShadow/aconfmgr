#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay a856562dc26bb1ea060e167983cd22ca6bcac9ec  # v12.4.2, libalpm v15 compatible
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
