#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage aurman 155a4007d89f7c4b8c5e9900bcdcd4478731a77b
AconfMakePkg aurman
TestAddConfig AddPackage --foreign aurman
TestAURHelper aurman "${XDG_CACHE_HOME:-$HOME/.cache}/aurman" false
TestDone
