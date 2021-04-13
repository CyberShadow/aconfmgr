#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay e6cfb6fc526e95aa379f2047e74e32299c00531a
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
