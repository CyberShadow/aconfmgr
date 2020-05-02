#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 21ea830c2a5ad413de0eb48efbacd59af25043e7
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
