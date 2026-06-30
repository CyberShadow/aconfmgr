#!/bin/bash
source ./lib.bash

# Test AUR functionality using aura.

TestNeedAUR
TestNeedAURPackage aura b42288b6040626c6ad81957fddcb4b6c41bc1c9a  # v4.0.8
AconfMakePkg aura
TestAddConfig AddPackage --foreign aura
TestAURHelper aura "${XDG_CACHE_HOME:-$HOME/.cache}/aura/cache" false
TestDone
