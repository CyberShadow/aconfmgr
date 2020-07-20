#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 755558fab7a4a9203fd82b8f972688eac9a6366d
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
