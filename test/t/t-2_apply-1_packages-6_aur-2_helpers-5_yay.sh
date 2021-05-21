#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 773d0d0dff4926fd4a6ef7969779b30f5bca4b57
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
