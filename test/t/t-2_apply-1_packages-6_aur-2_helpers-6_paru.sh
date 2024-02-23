#!/bin/bash
source ./lib.bash

# Test AUR functionality using paru.

TestNeedAUR
TestNeedAURPackage paru 2e1203f24e9aebf12e9abc6499b1f41745eb7f47
AconfMakePkg paru
TestAddConfig AddPackage --foreign paru
TestAURHelper paru "${XDG_CACHE_HOME:-$HOME/.cache}/paru" false
TestDone
