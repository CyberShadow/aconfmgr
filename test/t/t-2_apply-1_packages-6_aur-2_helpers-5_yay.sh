#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay bd6082f85f9a769defb424e4dd18ce4037b06ef0
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
