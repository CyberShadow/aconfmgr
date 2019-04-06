#!/bin/bash
source ./lib.bash

TestNeedAUR
TestAURHelper makepkg "$tmp_dir"/aur true
TestDone
