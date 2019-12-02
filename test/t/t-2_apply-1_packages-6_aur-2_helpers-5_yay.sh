#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay f2a571d9ee3f942af08c703d7747ccc55fa7a9df
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
