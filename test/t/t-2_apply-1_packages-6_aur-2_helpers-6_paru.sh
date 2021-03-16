#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage paru df1ab99585d054f532e6b7471012ba3e95d59704
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
