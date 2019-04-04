#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yaourt 67da8ff148bac693f98d8f3a2e2a2031c20e846f
TestNeedAURPackage package-query 98ce2515ad81e9d7efd444d4d61dfe00f5701100
AconfMakePkg yaourt true
TestAURHelper yaourt
