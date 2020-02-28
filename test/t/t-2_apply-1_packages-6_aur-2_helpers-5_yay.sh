#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 57b9ff9b60aebacb4e6a58c95e66dbf038e6b458
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
