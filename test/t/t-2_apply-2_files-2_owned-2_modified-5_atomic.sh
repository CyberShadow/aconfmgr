#!/bin/bash
source ./lib.bash

# Ensure that system files are updated atomically,
# and never leave the system in a broken state.

TestPhase_Setup ###############################################################
TestAddPackageFile test-package /dir/file.txt 'Original file contents'
TestAddPackage test-package native explicit
TestAddConfig AddPackage test-package
TestAddConfig 'echo "Modified file contents" > $(CreateFile /dir/file.txt)'

function sudo() {
	if ! test -f /dir/file.txt
	then
		FatalError 'Critical system file is gone! Mayday!\n'
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
diff -u <(cat /dir/file.txt) /dev/stdin <<<'Modified file contents'

TestDone ######################################################################
