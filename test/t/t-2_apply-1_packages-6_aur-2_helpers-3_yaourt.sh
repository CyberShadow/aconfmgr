#!/bin/bash
source ./lib.bash

# Test AUR functionality using yaourt.

TestNeedAUR
TestNeedAURPackage yaourt edf3615e311b6065b9eee29c9699ff6ed0f232b9
TestNeedAURPackage package-query b50d7ba02ee1e3d28b8069e0ed4ebc82221618b9
AconfMakePkg yaourt
TestAddConfig AddPackage --foreign yaourt
TestAURHelper yaourt '' false
TestDone
