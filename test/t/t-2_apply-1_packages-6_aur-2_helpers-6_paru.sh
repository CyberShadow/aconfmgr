#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 2bfa586c9fbf08144257c1e5c013481d43760e1a  # v2.0.3, alpm.rs 3.x, libalpm v14
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
