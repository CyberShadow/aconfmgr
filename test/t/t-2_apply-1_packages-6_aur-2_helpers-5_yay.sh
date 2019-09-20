#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 0caeae843268e6de0d784fbcaf68bfeb05fc26bd
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
