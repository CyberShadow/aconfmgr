#!/bin/bash
source ./lib.bash

TestNeedAUR
TestNeedAURPackage yay d7244687491ed935e4f7379e99af10f458b41f04
AconfMakePkg yay true
TestAURHelper yay
