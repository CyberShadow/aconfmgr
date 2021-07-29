#!/bin/bash
source ./lib.bash

TestNeedAUR
TestAURHelper makepkg "$aur_dir" true
TestDone
