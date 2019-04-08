# Common code for file matrix tests.

file_kinds=(
	[1]=file
	[2]=dir  # empty
	[3]=link # broken
	[4]=dir  # non-empty
	[5]=link # link to file
	[6]=link # link to dir
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

function TestMatrixEvalSpec() {
	local spec=$1

	if [[ "$spec" =~ ^(.)(.)-(.)(.)(.)(.)-(.)(.)(.)(.)-(.)(.)(.)(.)$ ]]
	then
		ignored="${BASH_REMATCH[1]}"
		priority="${BASH_REMATCH[2]}"

		p_present="${BASH_REMATCH[3]}"
		p_kind="${BASH_REMATCH[4]}"
		p_content="${BASH_REMATCH[5]}"
		p_attr="${BASH_REMATCH[6]}"

		f_present="${BASH_REMATCH[7]}"
		f_kind="${BASH_REMATCH[8]}"
		f_content="${BASH_REMATCH[9]}"
		f_attr="${BASH_REMATCH[10]}"

		c_present="${BASH_REMATCH[11]}"
		c_kind="${BASH_REMATCH[12]}"
		c_content="${BASH_REMATCH[13]}"
		c_attr="${BASH_REMATCH[14]}"

		fn=/dir/"$spec"
	else
		FatalError 'Invalid spec syntax: %s\n' "$spec"
	fi
}

function TestMatrixFileSetup() {
	declare -ag specs
	if [[ $# -gt 0 ]]
	then
		specs=("$@")
	else
		LogEnter 'Expanding specs...\n'
		specs=({0..1}{0..1}-{0..2}{1..6}{1..1}{1..1}-{0..1}{1..6}{1..2}{1..2}-{0..2}{1..6}{0..3}{1..3})
		LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"
	fi

	LogEnter 'Filtering specs...\n'
	[[ -v BASH_XTRACEFD ]] && set +x
	local specs2=()
	local spec
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		TestMatrixEvalSpec "$spec"

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

		# Cull varying type for content-less config files
		if [[ "$c_content" == 0 && "$c_kind" != 1 ]] ; then continue ; fi

		# Cull bad config: if a file is not in a package, asking to delete it doesn't make sense
		if [[ "$p_present" == 0 && "$c_present" == 2 ]] ; then continue ; fi

		# Cull bad config: if a package is about to get removed, simultaneously asking to remove a file in that package doesn't make sense
		if [[ "$p_present" == 1 && "$c_present" == 2 ]] ; then continue ; fi

		# Cull bad config: if we are not providing the content of some file in the config, it should be in a package
		if [[ "$c_content" == 0 && "$p_present" != 2 ]] ; then continue ; fi

		# Cull bad config: configurations should not mention a file if it is in the ignore list
		if [[ "$c_present" != 0 && "$ignored" == 1 ]] ; then continue ; fi

		# Cull bad config: can't overwrite a non-empty directory
		if [[ "$p_present" != 0 && "$c_present" == 1 && "$p_kind" == 4 && "$c_kind" != [24] ]] ; then continue ; fi
		if [[ "$f_present" != 0 && "$c_present" == 1 && "$f_kind" == 4 && "$c_kind" != [24] ]] ; then continue ; fi

		specs2+=("$spec")
	done
	specs=("${specs2[@]}")
	unset specs2
	[[ -v BASH_XTRACEFD ]] && set -x
	LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

	# Check that we didn't cull any given tests
	if [[ $# -gt 0 && "${#specs[@]}" -ne $# ]]
	then
		local -A saw_fn

		for spec in "${specs[@]}"
		do
			local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
			TestMatrixEvalSpec "$spec"
			saw_fn[$spec]=y
		done

		LogEnter 'Some tests were culled (%s/%s):\n' \
				 "$(Color G "${#specs[@]}")" \
				 "$(Color G $#)"
		local test
		for test in "$@"
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
		TestMatrixEvalSpec "$spec"

		if ((ignored))
		then
			ignore_paths+=("$fn" "$fn/*")
		fi

		if ((priority))
		then
			priority_files+=("$fn")
		fi

		if ((p_present))
		then
			TestMatrixAddObj test-package-"$p_present" "$fn" "$p_kind" "$p_content" "$p_attr"
		fi
	done
	LogLeave

	# Non-broken link targets
	local i
	for i in 1 2 3
	do
		TestAddPackageFile test-package-2 /f$i $i
		TestAddPackageDir test-package-2 /d$i
	done

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
		TestMatrixEvalSpec "$spec"

		if ((p_present))
		then
			TestDeleteFile "$fn"
		fi
		if ((f_present))
		then
			TestMatrixAddObj '' "$fn" "$f_kind" "$f_content" "$f_attr"
		fi

		if [[ $c_present == 1 ]]
		then
			if [[ $c_content == 0 ]]
			then
				TestAddConfig "$(printf 'SetFileProperty %q owner %q' \
										"$fn" "${file_users[$c_attr]}")"
				TestAddConfig "$(printf 'SetFileProperty %q group %q' \
										"$fn" "${file_users[$c_attr]}")"
				if [[ $p_kind != [356] ]]
				then
					TestAddConfig "$(printf 'SetFileProperty %q mode %q' \
											"$fn" "${file_modes[$c_attr]}")"
				fi
			else
				# shellcheck disable=SC2016
				case $c_kind in
					1) # file
						TestAddConfig "$(printf 'printf %%s %q > "$(CreateFile %q %q %q %q)"' \
												"$c_content" "$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						;;
					2) # empty dir
						TestAddConfig "$(printf 'CreateDir %q %q %q %q' \
												"$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						;;
					3) # broken link
						TestAddConfig "$(printf 'CreateLink %q %q %q %q' \
												"$fn" "$c_content" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						;;
					4) # non-empty dir
						TestAddConfig "$(printf 'CreateDir %q %q %q %q' \
												"$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						TestAddConfig "$(printf 'printf %%s %q > "$(CreateFile %q/%q)"' \
												"$c_content" "$fn" "$c_content")"
						;;
					5) # link to file
						TestAddConfig "$(printf 'CreateLink %q %q %q %q' \
												"$fn" "/f$c_content" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						;;
					6) # link to directory
						TestAddConfig "$(printf 'CreateLink %q %q %q %q' \
												"$fn" "/d$c_content" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
						;;
				esac

				if [[ $p_present == 2 && $p_kind == 4 && ( $c_kind != 4 || $p_content != "$c_content" ) ]]
				then
					TestAddConfig "$(printf 'SetFileProperty %q/%q deleted y' \
											"$fn" "$p_content")"
				fi
			fi
		elif [[ $c_present == 2 ]]
		then
			TestAddConfig "$(printf 'SetFileProperty %q deleted y' \
									"$fn")"
			if [[ $p_present == 2 && $p_kind == 4 ]]
			then
				TestAddConfig "$(printf 'SetFileProperty %q/%q deleted y' \
										"$fn" "$p_content")"
			fi
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

	local ocontent=$content
	[[ "$kind" != 2 ]] || content= # Directories may not have "content"
	[[ "$kind" != 4 ]] || content= # Ditto (but use content for file name)
	[[ "$kind" != 5 ]] || content=/f$content # Link to file
	[[ "$kind" != 6 ]] || content=/d$content # Link to dir

	local mode="${file_modes[$attr]}"
	[[ "$kind" != 3 ]] || mode= # Symlinks can't have a mode

	TestAddFSObj "$package" "$fn" "${file_kinds[$kind]}" "$content" "$mode" "${file_users[$attr]}" "${file_users[$attr]}"
	[[ "$kind" != 4 ]] || TestAddFSObj "$package" "$fn"/"$ocontent" file "$ocontent"
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
		2) # dir (empty)
			test -d "$path"
			diff <(stat --format=%a "$path") <(printf '%s\n' "${file_modes[$attr]}")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(find "$path" -mindepth 1 -printf '%P\n') /dev/null
			;;
		3) # link (broken)
			test -h "$path"
			diff <(readlink "$path") <(printf '%s\n' "$content")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
		4) # dir (non-empty)
			test -d "$path"
			diff <(stat --format=%a "$path") <(printf '%s\n' "${file_modes[$attr]}")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			sudo test -f "$path"/"$content"
			diff <(sudo find "$path" -mindepth 1 -printf '%P\n') <(printf '%s\n' "$content")
			;;
		5) # link to file
			test -h "$path"
			diff <(readlink "$path") <(printf '/f%s\n' "$content")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
		6) # link to dir
			test -h "$path"
			diff <(readlink "$path") <(printf '/d%s\n' "$content")
			diff <(stat --format=%U "$path") <(printf '%s\n' "${file_users[$attr]}")
			diff <(stat --format=%G "$path") <(printf '%s\n' "${file_users[$attr]}")
			;;
	esac
}

function TestMatrixFileCheckApply() {
	local spec
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		TestMatrixEvalSpec "$spec"

		LogEnter '%s\n' "$spec"
		if [[ $c_present == 2 ]] # Present as SetFileProperty deleted y
		then
			test ! -e "$fn" -a ! -h "$fn" # Must not exist
		elif [[ $c_present == 1 ]]
		then
			if [[ $c_content == 0 ]]
			then
				TestMatrixCheckObj "$fn" "$p_kind" "$p_content" "$c_attr" # Kind/content as in package, attr as in config
			else
				TestMatrixCheckObj "$fn" "$c_kind" "$c_content" "$c_attr" # Must be as in config
			fi
		elif [[ $f_present == 1 && $ignored == 1 && $p_present != 1 ]]
		then
			TestMatrixCheckObj "$fn" "$f_kind" "$f_content" "$f_attr" # Must be as in filesystem
		elif [[ $p_present == 2 ]]
		then
			TestMatrixCheckObj "$fn" "$p_kind" "$p_content" "$p_attr" # Must be as in package
		else
			test ! -e "$fn" -a ! -h "$fn" # Must not exist
		fi
		LogLeave 'OK!\n'
	done

	unset specs file_kinds file_modes file_users
}

function TestMatrixFileCheckRoundtrip() {
	local spec
	for spec in "${specs[@]}"
	do
		local ignored priority p_present p_kind p_content p_attr f_present f_kind f_content f_attr c_present c_kind c_content c_attr fn
		TestMatrixEvalSpec "$spec"

		LogEnter '%s\n' "$spec"
		if [[ $f_present == 0 ]]
		then
			test ! -e "$fn" -a ! -h "$fn" # Must not exist
		else
			TestMatrixCheckObj "$fn" "$f_kind" "$f_content" "$f_attr" # Must be as in filesystem
		fi
		LogLeave 'OK!\n'
	done

	unset specs file_kinds file_modes file_users
}
