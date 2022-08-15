#!/bin/bash
source ./lib.bash

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay 184c7d5d4b5ddb2d6509c8e2c0b26eff75ac2f4a
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
