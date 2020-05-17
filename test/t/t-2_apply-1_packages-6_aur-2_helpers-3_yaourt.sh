#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yaourt 67da8ff148bac693f98d8f3a2e2a2031c20e846f
TestNeedAURPackage package-query 61b06791c226f05514ac66f6b86961d16ce6b617
AconfMakePkg yaourt
TestAddConfig AddPackage --foreign yaourt
TestAURHelper yaourt '' false
TestDone
