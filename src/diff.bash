# diff.bash

# This file contains the implementation of aconfmgr's 'diff' command.

function AconfDiffRun() {
	local status=0
	"${diff_args[@]}" "$@" 1>&2 || status=$?
	if [[ "$status" -ne 0 && "$status" -ne 1 ]]
	then
		FatalError 'diff exited with status %d.\n' "$status"
	fi
}

function AconfDiff() {
	AconfCompileOutput
	AconfCompileSystem

	local diff_args=("${diff_opts[@]}" --unified --recursive --no-dereference)

	local found_path=false
	local arg
	for arg in "${aconfmgr_action_args[@]}"
	do
		if [[ "$arg" == -* ]]
		then
			# Assume this is an option to be passed to diff (such as -a)
			diff_args+=("$arg")
		elif [[ "$arg" == /* ]]
		then
			# Show diff for this path
			if [[ ! -e "$system_dir"/files"$arg" ]] && grep -qFx "$arg" "$tmp_dir"/owned-files
			then
				# File is owned by a package - retrieve package version
				local package
				package=$(pacman --quiet --query --owns "$arg")
				AconfGetPackageOriginalFile "$package" "$arg" |
					AconfDiffRun - "$output_dir"/files"$arg"
			elif [[ ! -e "$output_dir"/files"$arg" ]] && grep -qFx "$arg" "$tmp_dir"/owned-files
			then
				local package
				package=$(pacman --quiet --query --owns "$arg")
				AconfGetPackageOriginalFile "$package" "$arg" |
					AconfDiffRun "$system_dir"/files"$arg" -
			else
				AconfDiffRun "$system_dir"/files"$arg" "$output_dir"/files"$arg"
			fi
			found_path=true
		else
			FatalError 'Don'\''t know what to do with diff argument: %s\n' "$(Color Y "%q" "$arg")"
		fi
	done

	if ! $found_path
	then
		# This is currently too messy:
		if false
		then
			AconfDiffRun "$system_dir" "$output_dir"
		fi

		# For now, reserve argument-less invocation:
		FatalError 'Specify an absolute path to diff (or %s to diff all files).\n' "$(Color C /)"
	fi
}

: # include in coverage
