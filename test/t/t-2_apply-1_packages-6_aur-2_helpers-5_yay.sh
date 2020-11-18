#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 7153e7196b85a86d1b88fd0f059553a3bbb2b6fa
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
