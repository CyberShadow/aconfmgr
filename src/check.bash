# check.bash

# This file contains the implementation of aconfmgr's 'check' command.

function AconfCheck() {
	lint_config=true

	LogEnter 'Checking configuration...\n'

	AconfCompileOutput

	LogLeave 'Done (%s warnings).\n' "$(Color G "$(stat --format=%s "$output_dir"/warnings)")"
}

: # include in coverage
