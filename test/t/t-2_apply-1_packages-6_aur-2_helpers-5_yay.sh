#!/bin/bash
source ./lib.bash

# Test AUR functionality using yay.

TestNeedAUR
TestNeedAURPackage yay 4ef2cf06f02aa0fdca01be1c33b8e01811d91438
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
