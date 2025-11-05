#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using makepkg.

TestNeedAUR
TestAURHelper makepkg "$aur_dir" true
TestDone
