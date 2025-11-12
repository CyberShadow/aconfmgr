#!/bin/bash
source ./lib.bash

# Test AUR functionality using aura.

TestNeedAUR
TestNeedAURPackage aura 9f00c1bad581ba6a3e96158dfbbabd693a5ee179
AconfMakePkg aura
TestAddConfig AddPackage --foreign aura
TestAURHelper aura "${XDG_CACHE_HOME:-$HOME/.cache}/aura/cache" false
TestDone
