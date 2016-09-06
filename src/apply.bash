# apply.bash

function AconfApply() {
	modified=n

	AconfCompile

	LogEnter "Applying configuration...\n"

	#
	# Apply packages
	#

	LogEnter "Configuring packages...\n"

	#	in		in		in-
	#	config	system	stalled foreign	action
	#	----------------------------------------
	#	no		no		no		no		nothing
	#	no		no		no		yes		nothing
	#	no		no		yes		no		(prune)
	#	no		no		yes		yes		(prune)
	#	no		yes		no		no		impossible
	#	no		yes		no		yes		impossible
	#	no		yes		yes		no		unpin (and prune)
	#	no		yes		yes		yes		unpin (and prune)
	#	yes		no		no		no		install via pacman
	#	yes		no		no		yes		install via makepkg
	#	yes		no		yes		no		pin
	#	yes		no		yes		yes		pin
	#	yes		yes		no		no		impossible
	#	yes		yes		no		yes		impossible
	#	yes		yes		yes		no		nothing
	#	yes		yes		yes		yes		nothing

	# Unknown packages (native and foreign packages that are explicitly installed but not listed)
	unknown_packages=($(comm -13																			\
							 <((PrintArray           packages ; PrintArray           foreign_packages) | sort)	\
							 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort)))

	if [[ ${#unknown_packages[@]} != 0 ]]
	then
		LogEnter "Unpinning %s unknown packages.\n" "$(Color G ${#unknown_packages[@]})"

		function Details() { Log "Unpinning (setting install reason to 'as dependency') the following packages:%s\n" "$(Color M " %q" "${unknown_packages[@]}")" ; }
		Confirm Details

		Print0Array unknown_packages | sudo xargs -0 pacman --database --asdeps

		modified=y
		LogLeave
	fi

	# Missing packages (native and foreign packages that are listed in the configuration, but not marked as explicitly installed)
	missing_packages=($(comm -23																			\
							 <((PrintArray           packages ; PrintArray           foreign_packages) | sort)	\
							 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort)))

	# Missing installed/unpinned packages (native and foreign packages that are implicitly installed,
	# and listed in the configuration, but not marked as explicitly installed)
	missing_unpinned_packages=($(comm -12 <(PrintArray missing_packages) <(pacman --query --quiet | sort)))

	if [[ ${#missing_unpinned_packages[@]} != 0 ]]
	then
		LogEnter "Pinning %s unknown packages.\n" "$(Color G ${#missing_unpinned_packages[@]})"

		function Details() { Log "Pinning (setting install reason to 'explicitly installed') the following packages:%s\n" "$(Color M " %q" "${missing_unpinned_packages[@]}")" ; }
		Confirm Details

		Print0Array missing_unpinned_packages | sudo xargs -0 pacman --database --asexplicit

		modified=y
		LogLeave
	fi


	# Missing native packages (native packages that are listed in the configuration, but not installed)
	missing_native_packages=($(comm -23 <(PrintArray packages) <(pacman --query --quiet | sort)))

	if [[ ${#missing_native_packages[@]} != 0 ]]
	then
		LogEnter "Installing %s missing native packages.\n" "$(Color G ${#missing_native_packages[@]})"

		function Details() { Log "Installing the following native packages:%s\n" "$(Color M " %q" "${missing_native_packages[@]}")" ; }
		ParanoidConfirm Details

		AconfInstallNative "${missing_native_packages[@]}"

		modified=y
		LogLeave
	fi

	# Missing foreign packages (foreign packages that are listed in the configuration, but not installed)
	missing_foreign_packages=($(comm -23 <(PrintArray foreign_packages) <(pacman --query --quiet | sort)))

	if [[ ${#missing_foreign_packages[@]} != 0 ]]
	then
		LogEnter "Installing %s missing foreign packages.\n" "$(Color G ${#missing_foreign_packages[@]})"

		function Details() { Log "Installing the following foreign packages:%s\n" "$(Color M " %q" "${missing_foreign_packages[@]}")" ; }
		Confirm Details

		AconfInstallForeign "${missing_foreign_packages[@]}"

		modified=y
		LogLeave
	fi

	# Orphan packages

	if pacman --query --unrequired --unrequired --deps --quiet > /dev/null
	then
		LogEnter "Pruning orphan packages...\n"

		# We have to loop, since pacman's dependency scanning doesn't seem to be recursive
		iter=1
		while true
		do
			LogEnter "Iteration %s:\n" "$(Color G "$iter")"

			LogEnter "Querying orphan packages...\n"
			orphan_packages=($(pacman --query --unrequired --unrequired --deps --quiet || true))
			LogLeave

			if [[ ${#orphan_packages[@]} != 0 ]]
			then
				LogEnter "Pruning %s orphan packages.\n" "$(Color G ${#orphan_packages[@]})"

				function Details() { Log "Removing the following orphan packages:%s\n" "$(Color M " %q" "${orphan_packages[@]}")" ; }
				ParanoidConfirm Details

				sudo "${pacman_opts[@]}" --remove "${orphan_packages[@]}"
				LogLeave
			fi

			iter=$((iter+1))

			LogLeave # Iteration

			if [[ ${#orphan_packages[@]} == 0 ]]
			then
				break
			fi
		done

		modified=y
		LogLeave # Removing orphan packages
	fi

	LogLeave # Configuring packages

	#
	# Copy files
	#

	LogEnter "Configuring files...\n"

	function PrintFileProperty() {
		local kind="$1"
		local value="$2"
		local file="$3"

		value="${value:-(default value)}"

		Log "Setting %s of %s to %s\n"	\
			"$(Color Y "%s" "$kind")"	\
			"$(Color C "%q" "$file")"	\
			"$(Color G "%s" "$value")"
	}

	function ApplyFileProperty() {
		local kind="$1"
		local value="$2"
		local file="$3"

		PrintFileProperty "$kind" "$value" "$file"

		case "$kind" in
			mode)
				sudo chmod "${value:-$default_file_mode}" "$file"
				;;
			owner)
				sudo chown --no-dereference "${value:-root}" "$file"
				;;
			group)
				sudo chgrp --no-dereference "${value:-root}" "$file"
				;;
			*)
				Log "Unknown property %s with value %s for file %s"	\
					"$(Color Y "%q" "$kind")"						\
					"$(Color G "%q" "$value")"						\
					"$(Color C "%q" "$file")"
				exit 1
				;;
		esac
	}

	function ApplyFileProps() {
		local file="$1"
		local prop

		for prop in "${all_file_property_kinds[@]}"
		do
			local key="$file:$prop"
			if [[ -n "${output_file_props[$key]+x}" && ( -z "${system_file_props[$key]+x}" || "${output_file_props[$key]}" != "${system_file_props[$key]}" ) ]]
			then
				local value="${output_file_props[$key]}"
				ApplyFileProperty "$prop" "$value" "$file"
				unset "output_file_props[\$key]"
				unset "system_file_props[\$key]"
			fi
		done
	}

	if [[ ${#config_only_files[@]} != 0 || ${#changed_files[@]} != 0 ]]
	then
		LogEnter "Installing %s new and %s changed files.\n" "$(Color G ${#config_only_files[@]})" "$(Color G ${#changed_files[@]})"

		# shellcheck disable=2059
		function Details() {
			if [[ ${#config_only_files[@]} != 0 ]]
			then
				Log "Installing the following new files:\n"
				printf "$(Color W "*") $(Color C "%s" "%s")\n" "${config_only_files[@]}"
			fi
			
			if [[ ${#changed_files[@]} != 0 ]]
			then
				Log "Installing the following changed files:\n"
				printf "$(Color W "*") $(Color C "%s" "%s")\n" "${changed_files[@]}"
			fi
		}
		Confirm Details

		( Print0Array config_only_files ; Print0Array changed_files ) | \
			while read -r -d $'\n' file
			do
				sudo mkdir --parents "$(dirname /"$file")"
				sudo install --mode=$default_file_mode --owner=root --group=root "$output_dir"/files/"$file" /"$file"
				ApplyFileProps /"$file"
			done

		modified=y
		LogLeave
	fi

	if [[ ${#system_only_files[@]} != 0 ]]
	then
		LogEnter "Deleting %s extra files.\n" "$(Color G ${#system_only_files[@]})"

		# shellcheck disable=2059
		function Details() {
			Log "Deleting the following files:\n"
			printf "$(Color W "*") $(Color C "%s" "%s")\n" "${system_only_files[@]}"
		}
		Confirm Details

		for file in "${system_only_files[@]}"
		do
			sudo rm /"$file"
		done

		modified=y
		LogLeave
	fi

	#
	# Apply remaining file properties
	#

	LogEnter "Configuring file properties...\n"

	AconfCompareFileProps # Update data after ApplyFileProps' unsets

	if [[ ${#config_only_file_props[@]} != 0 || ${#changed_file_props[@]} != 0 || ${#system_only_file_props[@]} != 0 ]]
	then
		LogEnter "Found %s new, %s changed, and %s extra files properties.\n"	\
				 "$(Color G ${#config_only_file_props[@]})"						\
				 "$(Color G ${#changed_file_props[@]})" 						\
				 "$(Color G ${#system_only_file_props[@]})"

		function LogFileProps() {
			local verb="$1"
			local first=y
			local key

			while read -r -d $'\0' key
			do
				if [[ $first == y ]]
				then
					LogEnter "%s the following file properties:\n" "$verb"
					first=n
				fi
				
				local kind="${key##*:}"
				local file="${key%:*}"
				local value="${output_file_props[$key]:-}"
				PrintFileProperty "$kind" "$value" "$file"
			done

			if [[ $first == n ]]
			then
				LogLeave ''
			fi
		}

		# shellcheck disable=2059
		function Details() {
			Print0Array config_only_file_props | LogFileProps "Setting"
			Print0Array changed_file_props     | LogFileProps "Updating"
			Print0Array system_only_file_props | LogFileProps "Clearing"
		}
		Confirm Details

		( Print0Array config_only_file_props ; Print0Array changed_file_props ; Print0Array system_only_file_props ) | \
			while read -r -d $'\0' key
			do
				kind="${key##*:}"
				file="${key%:*}"
				value="${output_file_props[$key]:-}"
				# TODO: check if file exists first?
				ApplyFileProperty "$kind" "$value" "$file"
			done

		modified=y
		LogLeave
	fi

	LogLeave # Configuring file properties

	LogLeave # Configuring files

	if [[ $modified == n ]]
	then
		LogLeave "Done (%s).\n" "$(Color G "system state unchanged")"
	else
		LogLeave "Done (%s).\n" "$(Color Y "system state changed")"
	fi
}
