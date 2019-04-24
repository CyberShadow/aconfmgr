#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay d8b1c3b38dc0b5bf07e1b0a62519b845ba497f20
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
