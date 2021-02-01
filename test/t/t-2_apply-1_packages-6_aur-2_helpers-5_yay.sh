#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 4f61e7ce6a7ef3ca03710473720ea196a0e1163f
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
