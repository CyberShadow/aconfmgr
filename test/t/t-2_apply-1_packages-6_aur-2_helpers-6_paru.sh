#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru 8bfa71813071a9628407507caea525c971cdf741
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
