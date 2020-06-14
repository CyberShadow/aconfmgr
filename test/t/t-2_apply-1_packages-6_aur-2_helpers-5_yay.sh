#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay c5e6c3fd08ac7eb5512fd10feadd02602ab2f9ae
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
