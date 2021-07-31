#!/bin/bash
source ./lib.bash

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay a8f8d22c3581c8721afdcb631c1003a1984505ff
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
