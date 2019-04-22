# Common code for package matrix tests.

package_kinds=(
	[1]=native
	[2]=foreign
)

package_kind_switch=(
	[1]=''
	[2]=' --foreign'
)

package_dependences=(
	[1]=orphan
	[2]=dependency
	[3]=explicit
)

function TestMatrixPackageSetup() {
	if ((${ACONFMGR_INTEGRATION:-0}))
	then
		TestNeedAUR
	fi

	LogEnter 'Expanding specs...\n'
	declare -ag specs
	# shellcheck disable=SC2191
	specs=("
		"ignored={0..2}"

		"s_present={0..1}"
		"s_kind={1..2}"
		"s_dependence={1..3}"

		"c_present={0..1}"
		"c_kind={1..2}"
	")
	LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

	LogEnter 'Filtering specs...\n'
	[[ -v BASH_XTRACEFD ]] && set +x
	local specs2=()
	local spec
	# shellcheck disable=SC2154
	for spec in "${specs[@]}"
	do
		local ignored s_present s_kind s_dependence c_present c_kind name
		eval "$spec"

		# Cull varying properties of absent packages
		[[ "$s_present" == 1 || ( "$s_dependence" == 1 ) ]] || continue

		# Installing foreign packages is not mocked yet
		if [[ "$c_kind" == 2 && ${ACONFMGR_INTEGRATION:-0} -eq 0 ]] ; then continue ; fi

		# Cull bad config: configurations should not both ignore and install a package
		if [[ "$c_present" != 0 && "$ignored" != 0 ]] ; then continue ; fi

		# Cull bad config: installing mismatched package kind
		if [[ "$s_present" == 0 && "$c_present" == 1 && "$s_kind" != "$c_kind" ]] ; then continue ; fi

		name="$ignored-$s_present$s_kind$s_dependence-$c_present$c_kind"

		specs2+=("$spec name=$name")
	done
	specs=("${specs2[@]}")
	unset specs2
	[[ -v BASH_XTRACEFD ]] && set -x
	LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

	LogEnter 'Configuring packages...\n'
	# shellcheck disable=SC2154
	for spec in "${specs[@]}"
	do
		local ignored s_present s_kind s_dependence c_present c_kind name
		eval "$spec"

		local kind
		for kind in 1 2
		do
			TestCreatePackage "$name" "${package_kinds[$kind]}"
		done

		if ((s_present))
		then
			TestInstallPackage "$name" "${package_kinds[$s_kind]}" "${package_dependences[$s_dependence]}"
		fi

		if ((ignored))
		then
			TestAddConfig "$(printf 'IgnorePackage%s %q' \
			                        "${package_kind_switch[$ignored]}" "$name")"
		fi

		if ((c_present))
		then
			TestAddConfig "$(printf 'AddPackage%s %q' \
			                        "${package_kind_switch[$c_kind]}" "$name")"
		fi

		for kind in 1 2
		do
			if [[ "$kind" -ne "$c_kind" ]]
			then
				TestDeletePackage "$name" "${package_kinds[$kind]}"
			fi
		done
	done
	LogLeave
}

# shellcheck disable=SC2030,SC2031
function TestMatrixPackageCheckApply() {
	local -a packages=()
	( "$PACMAN" --query --quiet || true ) | mapfile -t packages
	local -A package_present
	local package
	for package in "${packages[@]}"
	do
		package_present[$package]=y
	done

	local spec
	for spec in "${specs[@]}"
	do
		local ignored s_present s_kind s_dependence c_present c_kind name
		eval "$spec"

		LogEnter '%s\n' "$name"

		local expected
		if ((c_present)) # In config
		then
			expected=y
		elif ((s_dependence==1)) # Orphan
		then
			expected=n
		elif ((s_present && ignored && c_kind == ignored)) # On system, but ignored (and ignoring the right kind)
		then
			expected=y
		elif ((s_present && s_dependence == 2)) # Dependency of pinned
		then
			expected=y
		else
			expected=n
		fi

		[[ "${package_present[$name]:-n}" == "$expected" ]] || \
			FatalError 'Wrong package installation state: expected %s, result %s\n' "$expected" "${package_present[$name]:-n}"
		LogLeave 'OK!\n'
	done

	unset specs package_kinds package_kind_switch package_dependences
}

# shellcheck disable=SC2030,SC2031
function TestMatrixPackageCheckRoundtrip() {
	local -a packages=()
	( "$PACMAN" --query --quiet || true ) | mapfile -t packages
	local -A package_present
	local package
	for package in "${packages[@]}"
	do
		package_present[$package]=y
	done

	local spec
	for spec in "${specs[@]}"
	do
		local ignored s_present s_kind s_dependence c_present c_kind name
		eval "$spec"

		LogEnter '%s\n' "$name"

		local expected
		if ((s_present && s_dependence > 1))
		then
			expected=y
		else
			expected=n
		fi

		[[ "${package_present[$name]:-n}" == "$expected" ]] || \
			FatalError 'Wrong package installation state: expected %s, result %s\n' "$expected" "${package_present[$name]:-n}"
		LogLeave 'OK!\n'
	done

	unset specs package_kinds package_kind_switch package_dependences
}
