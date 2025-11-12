#!/bin/bash
source ./lib.bash

# Test AUR functionality using aura.

TestNeedAUR
TestNeedAURPackage aura 32470a0fc37f10148cd480133c5d78e698321e6b  # v4.0.8
AconfMakePkg aura
TestAddConfig AddPackage --foreign aura
TestAURHelper aura "${XDG_CACHE_HOME:-$HOME/.cache}/aura/cache" false
TestDone
