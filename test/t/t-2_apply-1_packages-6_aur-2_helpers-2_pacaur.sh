#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage pacaur da18900a6fe888654867748fa976f8ae0ab96334
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 78e0ab5a1d51705e762b1ca5b409b30b82b897c9 'source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")'
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
