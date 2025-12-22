#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay 1a092538ebdfa373ddb641ab1fe564a2ed62877d  # v12.4.2, libalpm v15 compatible
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
