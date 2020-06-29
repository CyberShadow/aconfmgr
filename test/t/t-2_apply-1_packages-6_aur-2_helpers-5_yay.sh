#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 4e2a22bd62ade229db74f9bfe6a530d765af0dbc
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
