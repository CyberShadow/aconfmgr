# Common code for file matrix tests.

file_kinds=(
	[1]=file
	[2]=dir
	[3]=link
)
file_modes=(
	[1]=766
	[2]=776
	[3]=777
)
file_users=(
	[1]=root
	[2]=billy
	[3]=nobody
)

function TestMatrixFileSetup() {
	local test_list=("$@")
	local test_list_str=${test_list[*]}

	LogEnter 'Expanding specs...\n'
	declare -ag specs
	# shellcheck disable=SC2191
	specs=("
		"ignored={0..1}"
		"priority={0..1}"

		"p_present={0..2}"
		"p_kind={1..3}"
		"p_content={1..1}"
		"p_attr={1..1}"

		"f_present={0..1}"
		"f_kind={1..3}"
		"f_content={1..2}"
		"f_attr={1..2}"

		"c_present={0..2}"
		"c_kind={1..3}"
		"c_content={1..3}"
		"c_attr={1..3}"
	")
	LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

	LogEnter 'Filtering specs...\n'
	[[ -v BASH_XTRACEFD ]] && set +x
	local specs2=()
	local spec
	# shellcheck disable=SC2154
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		eval "$spec"

		# Cull varying properties of absent files
		[[ "$p_present" != 0 || ( "$p_kind" == 1 && "$p_content" == 1 && "$p_attr" == 1 ) ]] || continue
		[[ "$f_present" != 0 || ( "$f_kind" == 1 && "$f_content" == 2 && "$f_attr" == 2 ) ]] || continue
		[[ "$c_present" == 1 || ( "$c_kind" == 1 && "$c_content" == 3 && "$c_attr" == 3 ) ]] || continue

		# Cull using "same" properties as absent objects
		if [[ "$p_present" == 0 && ( "$f_content" == 1 || "$f_attr" == 1 ) ]] ; then continue ; fi
		if [[ "$p_present" == 0 && ( "$c_content" == 1 || "$c_attr" == 1 ) ]] ; then continue ; fi
		if [[ "$f_present" == 0 && ( "$c_content" == 2 || "$c_attr" == 2 ) ]] ; then continue ; fi

		# Cull varying content for directories
		[[ "$p_kind" != 2 || "$p_content" == 1 ]] || continue
		[[ "$f_kind" != 2 || "$f_content" == 2 ]] || continue
		[[ "$c_kind" != 2 || "$c_content" == 3 ]] || continue

		# Cull bad config: if a package is about to get removed, simultaneously asking to remove a file in that package doesn't make sense
		if [[ "$p_present" == 1 && "$c_present" == 2 ]] ; then continue ; fi

		# Cull bad config: configurations should not mention a file if it is in the ignore list
		if [[ "$c_present" != 0 && "$ignored" == 1 ]] ; then continue ; fi

		fn="$ignored$priority-$p_present$p_kind$p_content$p_attr-$f_present$f_kind$f_content$f_attr-$c_present$c_kind$c_content$c_attr"
		[[ -z "$test_list_str" || "$test_list_str" == *"$fn"* ]] || continue

		specs2+=("$spec fn=$fn")
	done
	specs=("${specs2[@]}")
	unset specs2
	[[ -v BASH_XTRACEFD ]] && set -x
	LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

	# Check that we didn't cull any given tests
	if [[ "${#test_list[@]}" -gt 0 && "${#specs[@]}" -ne "${#test_list[@]}" ]]
	then
		local -A saw_fn

		for spec in "${specs[@]}"
		do
			local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
			eval "$spec"
			saw_fn[$fn]=y
		done

		LogEnter 'Some tests were culled (%s/%s):\n' \
				 "$(Color G "${#specs[@]}")" \
				 "$(Color G "${#test_list[@]}")"
		local test
		for test in "${test_list[@]}"
		do
			if [[ -z "${saw_fn[$test]+x}" ]]
			then
				Log 'Test was not included: %q\n' "$test"
			fi
		done
		false
	fi

	LogEnter 'Creating package files...\n'
	# shellcheck disable=SC2154
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		eval "$spec"

		if ((ignored))
		then
			ignore_paths+=("/dir/$fn")
		fi

		if ((priority))
		then
			priority_files+=("/dir/$fn")
		fi

		if ((p_present))
		then
			[[ "$p_kind" != 2 ]] || p_content= # Directories may not have "content"
			TestMatrixAddObj test-package-"$p_present" "$fn" "$p_kind" "$p_content" "$p_attr"
		fi
	done
	LogLeave

	LogEnter 'Installing packages...\n'
	TestAddPackage test-package-1 native explicit
	TestAddPackage test-package-2 native explicit
	TestAddConfig AddPackage test-package-2
	LogLeave

	LogEnter 'Creating filesystem/config files...\n'
	# shellcheck disable=SC2154
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		eval "$spec"

		if ((p_present))
		then
			TestDeleteFile "/dir/$fn"
		fi
		if ((f_present))
		then
			[[ "$f_kind" != 2 ]] || f_content= # Directories may not have "content"
			TestMatrixAddObj '' "$fn" "$f_kind" "$f_content" "$f_attr"
		fi

		if [[ $c_present == 1 ]]
		then
			case $c_kind in
				1) # file
					# shellcheck disable=SC2016
					TestAddConfig "$(printf 'printf %%s %q > $(CreateFile /dir/%q %q %q %q)' \
											"$c_content" "$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
					;;
				2) # dir
					TestAddConfig "$(printf 'CreateDir /dir/%q %q %q %q' \
											"$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
					;;
				3) # link
					TestAddConfig "$(printf 'CreateLink /dir/%q %q %q %q' \
											"$fn" "$c_content" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
					;;
			esac
		elif [[ $c_present == 2 ]]
		then
			TestAddConfig "$(printf 'SetFileProperty /dir/%q deleted y' \
									"$fn")"
		fi
	done
	LogLeave
}

function TestMatrixAddObj() {
	local package=$1
	local fn=$2
	local kind=$3
	local content=$4
	local attr=$5

	local path=/dir/"$fn"
	local mode
	if [[ "$kind" == 3 ]] # link
	then
		mode= # symlinks can't have a mode
	else
		mode="${file_modes[$attr]}"
	fi

	TestAddFSObj "$package" "$path" "${file_kinds[$kind]}" "$f_content" "$mode" "${file_users[$attr]}" "${file_users[$attr]}"
}

function TestMatrixCheckObj() {
	local path=$1
	local kind=$2
	local content=$3
	local attr=$4

	case "$kind" in
		1) # file
			test -f "$path"
			diff "$path" <(printf %s "$content")
			diff <(stat --format=%a "$path") <(printf '%s\n' "${file_modes[$attr]}")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
		2) # dir
			test -d "$path"
			diff <(stat --format=%a "$path") <(printf '%s\n' "${file_modes[$attr]}")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
		3) # link
			test -h "$path"
			diff <(readlink "$path") <(printf '%s\n' "$content")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
	esac
}

function TestMatrixFileCheckApply() {
	# shellcheck disable=SC2154
	local spec
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		eval "$spec"

		Log '%s\n' "$fn"
		local path=/dir/"$fn"

		if [[ $c_present == 2 ]] # Present as SetFileProperty deleted y
		then
			test ! -e "$path" -a ! -h "$path" # Must not exist
		elif [[ $c_present == 1 ]]
		then
			TestMatrixCheckObj "$path" "$c_kind" "$c_content" "$c_attr" # Must be as in config
		elif [[ $f_present == 1 && $ignored == 1 ]]
		then
			TestMatrixCheckObj "$path" "$f_kind" "$f_content" "$f_attr" # Must be as in filesystem
		elif [[ $p_present == 2 ]]
		then
			TestMatrixCheckObj "$path" "$p_kind" "$p_content" "$p_attr" # Must be as in package
		else
			test ! -e "$path" -a ! -h "$path" # Must not exist
		fi
	done

	unset specs file_kinds file_modes file_users
}
