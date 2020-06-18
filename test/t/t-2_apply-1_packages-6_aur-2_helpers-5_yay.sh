#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 8f9f8b9276c6c5d3e1798473de0f8a9567535b7f
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
