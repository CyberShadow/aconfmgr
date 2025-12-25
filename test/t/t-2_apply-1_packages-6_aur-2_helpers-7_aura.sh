#!/bin/bash
source ./lib.bash

# Test AUR functionality using aura.

TestNeedAUR
TestNeedAURPackage aura fafd3f336bd295ebc595a7e0650abfb84fbe0863  # v4.0.8
AconfMakePkg aura
TestAddConfig AddPackage --foreign aura
TestAURHelper aura "${XDG_CACHE_HOME:-$HOME/.cache}/aura/cache" false
TestDone
