#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yaourt edf3615e311b6065b9eee29c9699ff6ed0f232b9
TestNeedAURPackage package-query 61b06791c226f05514ac66f6b86961d16ce6b617
AconfMakePkg yaourt
TestAddConfig AddPackage --foreign yaourt
TestAURHelper yaourt '' false
TestDone
