#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay ffe46319a7fa3adf05194f70dfdda93ae981fe31
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
