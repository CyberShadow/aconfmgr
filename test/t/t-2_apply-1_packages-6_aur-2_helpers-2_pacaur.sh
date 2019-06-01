#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage pacaur da18900a6fe888654867748fa976f8ae0ab96334
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 0edc474c5acf43635aed4899da1d100fe061d602 'source=("${source[@]/%/#commit=4f90e0fb38e21e9037ccbbe4afa34d3b5299cfa2}")'
AconfMakePkg pacaur
TestAddConfig AddPackage --foreign pacaur
TestAURHelper pacaur "${XDG_CACHE_HOME:-$HOME/.cache}/pacaur" true
TestDone
