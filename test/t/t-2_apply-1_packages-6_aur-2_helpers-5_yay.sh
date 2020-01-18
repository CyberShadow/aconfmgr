#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay 05a3140025672fcbf684f704e6b062dce483003a
AconfMakePkg yay
TestAddConfig AddPackage --foreign yay
TestAURHelper yay "${XDG_CACHE_HOME:-$HOME/.cache}/yay" false
TestDone
