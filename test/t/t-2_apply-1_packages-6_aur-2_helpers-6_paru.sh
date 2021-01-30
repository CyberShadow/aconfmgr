#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 614d6cc9f24fb8e91fcb2ceb41839c749caca28c
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
