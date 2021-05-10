#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay bd7006c9db8be31f07540a854558299f2c795a57
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
