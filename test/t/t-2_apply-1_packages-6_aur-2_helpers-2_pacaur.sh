#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage pacaur da18900a6fe888654867748fa976f8ae0ab96334
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 0edc474c5acf43635aed4899da1d100fe061d602 'source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")'
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
