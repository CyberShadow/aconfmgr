#!/usr/bin/env bash
source ./lib.bash

# Test AUR functionality using makepkg.

TestNeedAUR
TestAURHelper makepkg "$aur_dir" true
TestDone
