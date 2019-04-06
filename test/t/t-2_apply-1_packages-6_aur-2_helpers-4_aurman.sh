#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage aurman 62160314c33f6d60c7f04c3085ea327df95ba5b1
AconfMakePkg aurman
TestAddConfig AddPackage --foreign aurman
TestAURHelper aurman "${XDG_CACHE_HOME:-$HOME/.cache}/aurman" false
TestDone
