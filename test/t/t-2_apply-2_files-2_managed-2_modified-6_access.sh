#!/bin/bash
source ./lib.bash

# Ensure that there is never a window in which installed files which
# should not be world-readable are world-readable.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /dir/file.txt 'Original file contents' 600
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddConfig 'echo "Modified file contents" > $(CreateFile /dir/file.txt 600)'

function sudo() {
	local mode
	mode=$( ( stat --format=%a /dir/file.txt.aconfmgr-new || stat --format=%a /dir/file.txt ) 2>/dev/null)
	if [[ "$mode" != 600 ]]
	then
		FatalError 'Critical system file is world-readable (%s)! Mayday!\n' "$mode"
	fi

	if ((${ACONFMGR_INTEGRATION:-0}))
	then
		command sudo "$@"
	else
		"$@"
	fi
}

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(sudo cat /dir/file.txt) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
