#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 5475032cf53565edba44834b6af4165833cd687d
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
