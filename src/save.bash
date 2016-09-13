# save.bash

# This file contains the implementation of aconfmgr's 'save' command.

function AconfSave() {
	config_save_target=$config_dir/99-unsorted.sh
	modified=n

	AconfCompile

	LogEnter "Saving configuration...\n"

	#
	# Packages
	#

	LogEnter "Examining packages...\n"

	# Unknown native packages (installed but not listed)

	unknown_packages=($(comm -13 <(PrintArray packages) <(PrintArray installed_packages)))

	if [[ ${#unknown_packages[@]} != 0 ]]
	then
		LogEnter "Found %s unknown packages. Registering...\n" "$(Color G ${#unknown_packages[@]})"
		printf "\n\n# %s - Unknown packages\n\n\n" "$(date)" >> "$config_save_target"
		for package in "${unknown_packages[@]}"
		do
			Log "%s...\r" "$(Color M "%q" "$package")"
			local description
			description="$(pacman --query --info "$package" | grep '^Description' | cut -d ':' -f 2)"
			printf "AddPackage %q #%s\n" "$package" "$description" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Missing native packages (listed but not installed on current system)

	missing_packages=($(comm -23 <(PrintArray packages) <(PrintArray installed_packages)))

	if [[ ${#missing_packages[@]} != 0 ]]
	then
		LogEnter "Found %s missing packages. Un-registering.\n" "$(Color G ${#missing_packages[@]})"
		printf "\n\n# %s - Missing packages\n\n\n" "$(date)" >> "$config_save_target"
		for package in "${missing_packages[@]}"
		do
			printf "RemovePackage %q\n" "$package" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Unknown foreign packages (installed but not listed)

	unknown_foreign_packages=($(comm -13 <(PrintArray foreign_packages) <(PrintArray installed_foreign_packages)))

	if [[ ${#unknown_foreign_packages[@]} != 0 ]]
	then
		LogEnter "Found %s unknown foreign packages. Registering...\n" "$(Color G ${#unknown_foreign_packages[@]})"
		printf "\n\n# %s - Unknown foreign packages\n\n\n" "$(date)" >> "$config_save_target"
		for package in "${unknown_foreign_packages[@]}"
		do
			Log "%s...\r" "$(Color M "%q" "$package")"
			local description
			description="$(pacman --query --info "$package" | grep '^Description' | cut -d ':' -f 2)"
			printf "AddPackage --foreign %q #%s\n" "$package" "$description" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Missing foreign packages (listed but not installed on current system)

	missing_foreign_packages=($(comm -23 <(PrintArray foreign_packages) <(PrintArray installed_foreign_packages)))

	if [[ ${#missing_foreign_packages[@]} != 0 ]]
	then
		LogEnter "Found %s missing foreign packages. Un-registering.\n" "$(Color G ${#missing_foreign_packages[@]})"
		printf "\n\n# %s - Missing foreign packages\n\n\n" "$(date)" >> "$config_save_target"
		for package in "${missing_foreign_packages[@]}"
		do
			printf "RemovePackage --foreign %q\n\n" "$package" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	LogLeave # Examining packages

	#
	# Emit files
	#

	LogEnter "Registering files...\n"

	function PrintFileProps() {
		local file="$1"
		local prop
		local printed=n

		for prop in "${all_file_property_kinds[@]}"
		do
			local key="$file:$prop"
			if [[ -n "${system_file_props[$key]+x}" && ( -z "${output_file_props[$key]+x}" || "${system_file_props[$key]}" != "${output_file_props[$key]}" ) ]]
			then
				printf "SetFileProperty %q %q %q\n" "$file" "$prop" "${system_file_props[$key]}" >> "$config_save_target"
				unset "output_file_props[\$key]"
				unset "system_file_props[\$key]"
				printed=y
			fi
		done

		if [[ $printed == y ]]
		then
			printf "\n" >> "$config_save_target"
		fi
	}

	if [[ ${#system_only_files[@]} != 0 || ${#changed_files[@]} != 0 ]]
	then
		LogEnter "Found %s new and %s changed files.\n" "$(Color G ${#system_only_files[@]})" "$(Color G ${#changed_files[@]})"
		printf "\n\n# %s - New files\n\n\n" "$(date)" >> "$config_save_target"
		( Print0Array system_only_files ; Print0Array changed_files ) | \
			while read -r -d $'\0' file
			do
				local dir
				dir="$(dirname "$file")"
				mkdir --parents "$config_dir"/files/"$dir"

				system_file="$system_dir"/files/"$file"
				type=$(stat --format=%F "$system_file")
				if [[ "$type" == "symbolic link" ]]
				then
					printf "CreateLink %q %q\n" "$file" "$(readlink "$system_file")" >> "$config_save_target"
				else
					size=$(stat --format=%s "$system_file")
					if [[ $size == 0 ]]
					then
						printf ": \$(CreateFile %q)\n" "$file" >> "$config_save_target"
					else
						cp "$system_file" "$config_dir"/files/"$file"
						printf "CopyFile %q \n" "$file" >> "$config_save_target"
					fi

				fi

				PrintFileProps "$file"
			done
		modified=y
		LogLeave
	fi

	if [[ ${#config_only_files[@]} != 0 ]]
	then
		LogEnter "Found %s extra files.\n" "$(Color G ${#config_only_files[@]})"
		printf "\n\n# %s - Extra files\n\n\n" "$(date)" >> "$config_save_target"
		for file in "${config_only_files[@]}"
		do
			printf "RemoveFile %q\n" "$file" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	LogLeave # Emit files

	#
	# Emit remaining file properties
	#

	LogEnter "Registering file properties...\n"

	AconfCompareFileProps # Update data after PrintFileProps' unsets

	if [[ ${#system_only_file_props[@]} != 0 || ${#changed_file_props[@]} != 0 ]]
	then
		printf "\n\n# %s - New file properties\n\n\n" "$(date)" >> "$config_save_target"
		( ( Print0Array system_only_file_props ; Print0Array changed_file_props ) | sort --zero-terminated ) | \
			while read -r -d $'\0' key
			do
				printf "SetFileProperty %q %q %q\n" "${key%:*}" "${key##*:}" "${system_file_props[$key]}" >> "$config_save_target"
			done
		modified=y
	fi

	if [[ ${#config_only_file_props[@]} != 0 ]]
	then
		printf "\n\n# %s - Extra file properties\n\n\n" "$(date)" >> "$config_save_target"
		( Print0Array config_only_file_props | sort --zero-terminated ) | \
			while read -r -d $'\0' key
			do
				printf "SetFileProperty %q %q %q\n" "${key%:*}" "${key##*:}" '' >> "$config_save_target"
			done
		modified=y
	fi

	LogLeave # Registering file properties

	if [[ $modified == n ]]
	then
		LogLeave "Done (%s).\n" "$(Color G "configuration unchanged")"
	else
		LogLeave "Done (%s).\n" "$(Color Y "configuration changed")"
	fi
}
