#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage aurman e0fa0132b0c622806298d466736f71cd48704978
AconfMakePkg aurman
TestAddConfig AddPackage --foreign aurman
TestAURHelper aurman "${XDG_CACHE_HOME:-$HOME/.cache}/aurman" false
TestDone
