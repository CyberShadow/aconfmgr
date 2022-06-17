#!/bin/bash
source ./lib.bash

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay 76f0c3a7a8a9d7a0b5382716aacb16fc8e01b2b8
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
