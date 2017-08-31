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
			description="$(LC_ALL=C "$PACMAN" --query --info "$package" | grep '^Description' | cut -d ':' -f 2)"
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
			description="$(LC_ALL=C "$PACMAN" --query --info "$package" | grep '^Description' | cut -d ':' -f 2)"
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
			printf "RemovePackage --foreign %q\n" "$package" >> "$config_save_target"
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

	# Don't emit redundant CreateDir lines
	local -A skip_dirs
	( Print0Array system_only_files ; Print0Array changed_files ) | \
		while read -r -d $'\0' file
		do
			local path=${file%/*}
			while [[ -n "$path" ]]
			do
				skip_dirs[$path]=y
				path=${path%/*}
			done
		done

	if [[ ${#system_only_files[@]} != 0 || ${#changed_files[@]} != 0 ]]
	then
		LogEnter "Found %s new and %s changed files.\n" "$(Color G ${#system_only_files[@]})" "$(Color G ${#changed_files[@]})"
		printf "\n\n# %s - New files\n\n\n" "$(date)" >> "$config_save_target"
		( Print0Array system_only_files ; Print0Array changed_files ) | \
			while read -r -d $'\0' file
			do
				if [[ -n ${skip_dirs[$file]+x} ]]
				then
					continue
				fi

				local dir
				dir="$(dirname "$file")"
				mkdir --parents "$config_dir"/files/"$dir"

				local func args props suffix=''

				local system_file type
				system_file="$system_dir"/files/"$file"
				type=$(LC_ALL=C stat --format=%F "$system_file")
				if [[ "$type" == "symbolic link" ]]
				then
					func=CreateLink
					args=("$file" "$(readlink "$system_file")")
					props=(owner group)
				elif [[ "$type" == "directory" ]]
				then
					func=CreateDir
					args=("$file")
					props=(mode owner group)
				else
					size=$(LC_ALL=C stat --format=%s "$system_file")
					if [[ $size == 0 ]]
					then
						func=CreateFile
						suffix=' > /dev/null'
					else
						cp "$system_file" "$config_dir"/files/"$file"
						func=CopyFile
					fi
					args=("$file")
					props=(mode owner group)
				fi

				# Calculate the optional function parameters
				local prop
				for prop in "${props[@]}"
				do
					local key="$file:$prop"
					if [[ -n "${system_file_props[$key]+x}" && ( -z "${output_file_props[$key]+x}" || "${system_file_props[$key]}" != "${output_file_props[$key]}" ) ]]
					then
						args+=("${system_file_props[$key]}")
						unset "output_file_props[\$key]"
						unset "system_file_props[\$key]"
					else
						args+=('')
					fi
				done

				# Trim redundant blank parameters
				while [[ -z "${args[-1]}" ]]
				do
					unset args[${#args[@]}-1]
				done

				printf "%s%s%s\n" "$func" "$(printf " %q" "${args[@]}")" "$suffix" >> "$config_save_target"

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
