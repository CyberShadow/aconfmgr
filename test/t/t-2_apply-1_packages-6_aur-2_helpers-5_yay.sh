#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 525c01b5b2d183cc0157ed3ca38541e55392c001
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
