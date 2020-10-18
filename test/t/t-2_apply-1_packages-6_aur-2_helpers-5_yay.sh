#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay e02698c2e2a7a3b208493405dc9f91ba59b3a26e
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
