#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yaourt 67da8ff148bac693f98d8f3a2e2a2031c20e846f
TestNeedAURPackage package-query 9ab0eed4d5a04951ac033589bbde8ea263ce0045
AconfMakePkg yaourt
TestAddConfig AddPackage --foreign yaourt
TestAURHelper yaourt '' false
TestDone
