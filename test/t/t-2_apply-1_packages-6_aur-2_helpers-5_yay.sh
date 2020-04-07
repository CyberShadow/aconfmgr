#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay e9022a26ee3d7e50f2f47db22d3149d1a549ec24
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
