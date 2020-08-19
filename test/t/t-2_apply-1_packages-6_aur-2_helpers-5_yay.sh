#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay eb2dca24550aa3d9e0ef275c6d6caa73d1ac19d2
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
