# diff.bash

# This file contains the implementation of aconfmgr's 'diff' command.

# Run diff, and record whether it found any differences
# (in AconfDiff's found_differences).
function AconfDiffRun() {
	local status=0
	"${diff_args[@]}" "$@" 1>&2 || status=$?
	case "$status" in
		0)
			;;
		1)
			found_differences=true
			;;
		*)
			FatalError 'diff exited with status %d.\n' "$status"
			;;
	esac
}

# Like AconfDiffRun, but substitutes the original version
# of the given file from its package for "-" in the arguments.
function AconfDiffRunWithOriginal() {
	local file=$1
	shift

	local package
	package=$(pacman --quiet --query --owns "$file")

	# Not piped into diff directly, as that would run AconfDiffRun in a subshell.
	local original="$tmp_dir"/diff-original
	AconfGetPackageOriginalFile "$package" "$file" > "$original"
	AconfDiffRun "$@" < "$original"
	rm "$original"
}

function AconfDiff() {
	AconfCompileOutput
	AconfCompileSystem

	local diff_args=("${diff_opts[@]}" --unified --recursive --no-dereference)

	local found_path=false
	local found_differences=false
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
				AconfDiffRunWithOriginal "$arg" - "$output_dir"/files"$arg"
			elif [[ ! -e "$output_dir"/files"$arg" ]] && grep -qFx "$arg" "$tmp_dir"/owned-files
			then
				AconfDiffRunWithOriginal "$arg" "$system_dir"/files"$arg" -
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

	# Like diff, exit with status 1 if there were any differences.
	if $found_differences
	then
		Exit 1
	fi
}

: # include in coverage
