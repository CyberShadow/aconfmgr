#!/bin/bash
source ./lib.bash

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay a62850c2735d8199c22546bf772ebfec03883ed3
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
