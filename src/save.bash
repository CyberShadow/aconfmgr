# save.bash

# This file contains the implementation of aconfmgr's 'save' command.

function AconfSave() {
	local config_save_target=$config_dir/99-unsorted.sh
	local modified=n

	AconfCompile

	LogEnter 'Saving configuration...\n'

	#
	# Packages
	#

	LogEnter 'Examining packages...\n'

	# Unknown native packages (installed but not listed)

	local -a unknown_packages
	comm -13 <(PrintArray packages) <(PrintArray installed_packages) | mapfile -t unknown_packages

	if [[ ${#unknown_packages[@]} != 0 ]]
	then
		LogEnter 'Found %s unknown packages. Registering...\n' "$(Color G ${#unknown_packages[@]})"
		printf '\n\n# %s - Unknown packages\n\n\n' "$(date)" >> "$config_save_target"
		local package
		for package in "${unknown_packages[@]}"
		do
			Log '%s...\r' "$(Color M "%q" "$package")"
			local description
			description="$(LC_ALL=C "$PACMAN" --query --info "$package" | grep '^Description' | cut -d ':' -f 2-)"
			printf 'AddPackage %q #%s\n' "$package" "$description" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Missing native packages (listed but not installed on current system)

	local -a missing_packages
	comm -23 <(PrintArray packages) <(PrintArray installed_packages) | mapfile -t missing_packages

	if [[ ${#missing_packages[@]} != 0 ]]
	then
		LogEnter 'Found %s missing packages. Un-registering.\n' "$(Color G ${#missing_packages[@]})"
		printf '\n\n# %s - Missing packages\n\n\n' "$(date)" >> "$config_save_target"
		local package
		for package in "${missing_packages[@]}"
		do
			printf 'RemovePackage %q\n' "$package" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Unknown foreign packages (installed but not listed)

	local -a unknown_foreign_packages
	comm -13 <(PrintArray foreign_packages) <(PrintArray installed_foreign_packages) | mapfile -t unknown_foreign_packages

	if [[ ${#unknown_foreign_packages[@]} != 0 ]]
	then
		LogEnter 'Found %s unknown foreign packages. Registering...\n' "$(Color G ${#unknown_foreign_packages[@]})"
		printf '\n\n# %s - Unknown foreign packages\n\n\n' "$(date)" >> "$config_save_target"
		local package
		for package in "${unknown_foreign_packages[@]}"
		do
			Log '%s...\r' "$(Color M "%q" "$package")"
			local description
			description="$(LC_ALL=C "$PACMAN" --query --info "$package" | grep '^Description' | cut -d ':' -f 2-)"
			printf 'AddPackage --foreign %q #%s\n' "$package" "$description" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	# Missing foreign packages (listed but not installed on current system)

	local -a missing_foreign_packages
	comm -23 <(PrintArray foreign_packages) <(PrintArray installed_foreign_packages) | mapfile -t missing_foreign_packages

	if [[ ${#missing_foreign_packages[@]} != 0 ]]
	then
		LogEnter 'Found %s missing foreign packages. Un-registering.\n' "$(Color G ${#missing_foreign_packages[@]})"
		printf '\n\n# %s - Missing foreign packages\n\n\n' "$(date)" >> "$config_save_target"
		local package
		for package in "${missing_foreign_packages[@]}"
		do
			printf 'RemovePackage --foreign %q\n' "$package" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	LogLeave # Examining packages

	#
	# Emit files
	#

	LogEnter 'Registering files...\n'

	# Don't emit redundant CreateDir lines
	local -A skip_dirs
	local file
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

	if [[ ${#config_only_files[@]} != 0 ]]
	then
		LogEnter 'Found %s extra files.\n' "$(Color G ${#config_only_files[@]})"
		printf '\n\n# %s - Extra files\n\n\n' "$(date)" >> "$config_save_target"
		local i
		for ((i=${#config_only_files[@]}-1; i>=0; i--))
		do
			file=${config_only_files[$i]}
			printf 'RemoveFile %q\n' "$file" >> "$config_save_target"
		done
		modified=y
		LogLeave
	fi

	if [[ ${#system_only_files[@]} != 0 || ${#changed_files[@]} != 0 ]]
	then
		LogEnter 'Found %s new and %s changed files.\n' "$(Color G ${#system_only_files[@]})" "$(Color G ${#changed_files[@]})"
		printf '\n\n# %s - New / changed files\n\n\n' "$(date)" >> "$config_save_target"
		local file
		( Print0Array system_only_files ; Print0Array changed_files ) | \
			while read -r -d $'\0' file
			do
				if [[ -n ${skip_dirs[$file]+x} ]]
				then
					continue
				fi

				local dir
				dir="$(dirname "$file")"
				# shellcheck disable=SC2174
				mkdir --mode=700 --parents "$config_dir"/files/"$dir"

				local func suffix heredoc_src prefix_to_expand args=() props=()

				local output_file="$output_dir"/files/"$file"
				local system_file="$system_dir"/files/"$file"

				local need_remove
				if ! [[ -h "$output_file" || -e "$output_file" ]]
				then
					need_remove=false # don't need RemoveFile if it doesn't exist
				elif [[ -h "$output_file" || -h "$system_file" ]]
				then
					need_remove=true # always need RemoveFile for symlinks
				elif [[ ( -d "$output_file" && -d "$system_file" ) || ( -f "$output_file" && -f "$system_file" ) ]]
				then
					need_remove=false # don't need RemoveFile if both are files or both are directories
				else
					need_remove=true
				fi

				if $need_remove
				then
					printf 'RemoveFile %q # Replacing %s with %s\n' "$file" \
						   "$(LC_ALL=C stat --format=%F "$output_file")" \
						   "$(LC_ALL=C stat --format=%F "$system_file")" \
						   >> "$config_save_target"
				fi

				if [[ -h "$system_file" ]]
				then
					func=CreateLink
					args=("$file" "$(readlink "$system_file")")
					props=(owner group)
				elif [[ -d "$system_file" ]]
				then
					func=CreateDir
					args=("$file")
					props=(mode owner group)
				else
					local size package
					size="$(LC_ALL=C stat --format=%s "$system_file")"
					package="$(pacman -Qoq "$file" 2>/dev/null || true)"
					if [[ $size -eq 0 ]]
					then
						func=CreateFile
						args=("$file")
						props=(mode owner group)
						suffix=' > /dev/null'

						if [[ -h "$output_file" || -e "$output_file" ]]
						then
							printf 'RemoveFile %q\n' "$file" >> "$config_save_target"
						fi
					elif
						{
							AconfNeedProgram file file n;
							[[ $(wc -w <<<"$package") -le 1 ]] &&
							file "$system_file" | LC_ALL=C grep -Fw text | LC_ALL=C grep -qvFw 'with escape sequences';
						}
					then
						AconfNeedProgram diff diffutils n
						if [[ -n "$package" ]]
						then
							AconfNeedPackageFile "$package" >/dev/null
							function GetOutputFileElsePackageFile() {
								if [[ -f "$output_file" ]]
								then
									cat "$output_file"
								else
									AconfGetPackageOriginalFile "$package" "$file"
								fi
							}
							{
								# the output should contain a quoted command expansion
								# shellcheck disable=SC2016
								printf 'patch --no-backup-if-mismatch "$(GetPackageOriginalFile --no-clobber %s %q)" <<"EOF"\n' "$package" "$file"
 								diff --unified=5 --label "output/$file" --label "system/$file" \
									<(GetOutputFileElsePackageFile) "$system_file" || true;
 								printf 'EOF\n'
								# we didn't have to worry about heredoc delimiter collisions because
								# unified diff lines always begin with space, plus or minus
							} >> "$config_save_target"
						elif [[ -f "$output_file" ]]
						then
							{
								# the output should contain a quoted command expansion
								# shellcheck disable=SC2016
								printf 'patch --no-backup-if-mismatch "$(CreateFile --no-clobber %q)" <<"EOF"\n' "$file"
								diff --unified=5 --label "output/$file" --label "system/$file" \
									"$output_file" "$system_file" || true;
								printf 'EOF\n'
								# we didn't have to worry about heredoc delimiter collisions because
								# unified diff lines always begin with space, plus or minus
							} >> "$config_save_target"
						else
							func=CreateFile
							args=("$file")
							props=(mode owner group)
							prefix_to_expand='cat >'
 							if [[ -f "$output_file" ]]
							then
								heredoc_src="$output_file"
							else
								heredoc_src="$system_file"
							fi
							local contents
							case "$(head -n2 "$heredoc_src" | wc -l)" in
								0|1)
									contents=$(<"$heredoc_src")
									unset heredoc_src
									prefix_to_expand="printf '%s\n' -- ${contents@Q} >"
								;;&
								0)
									prefix_to_expand="printf '%s' -- ${contents@Q} >"
								;;
							esac
						fi
					else
						cp "$system_file" "$config_dir"/files/"$file"
						func=CopyFile
						args=("$file")
						props=(mode owner group)
					fi
				fi

				# Calculate the optional function parameters
				local prop
				for prop in "${props[@]}"
				do
					local key="$file:$prop"
					if [[ -n "${system_file_props[$key]+x}" ]]
					then
						args+=("${system_file_props[$key]}")
						unset "output_file_props[\$key]"
						unset "system_file_props[\$key]"
					else
						args+=('')
					fi
				done

				# Trim redundant blank parameters
				while [[ "${#args[*]}" -gt 0 && -z "${args[-1]}" ]]
				do
					unset 'args[${#args[@]}-1]'
				done

				if [[ -v $func ]]
				then
					if [[ -v "$prefix_to_expand" ]]
					then
						if [[ -v "$heredoc_src" ]]
						then
							local heredoc_delim
							heredoc_delim="$(ChooseHeredocTerminator "$heredoc_src")"
							# the output should contain a quoted command expansion
							# shellcheck disable=SC2016
							printf '%s "$(%s%s%s)" <<"%s"\n' "$prefix_to_expand" "$func" "$(printf ' %q' "${args[@]}")" "$suffix" "$heredoc_delim"
							# use sed to enforce trailing newline, via https://unix.stackexchange.com/a/31955
							# shellcheck disable=SC1003
							sed -e '$a\' "$heredoc_src"
							printf '%s\n' "$heredoc_delim"
						else
							# shellcheck disable=SC2016
							printf '%s "$(%s%s%s)"\n' "$prefix_to_expand" "$func" "$(printf ' %q' "${args[@]}")" "$suffix"
						fi
					else
						printf '%s%s%s\n' "$func" "$(printf ' %q' "${args[@]}")" "$suffix"
					fi >> "$config_save_target"
				fi
			done
		modified=y
		LogLeave
	fi

	LogLeave # Emit files

	#
	# Emit remaining file properties
	#

	LogEnter 'Registering file properties...\n'

	AconfCompareFileProps # Update data after above unsets

	if [[ ${#system_only_file_props[@]} != 0 || ${#changed_file_props[@]} != 0 ]]
	then
		printf '\n\n# %s - New file properties\n\n\n' "$(date)" >> "$config_save_target"
		local key
		( ( Print0Array system_only_file_props ; Print0Array changed_file_props ) | sort --zero-terminated ) | \
			while read -r -d $'\0' key
			do
				printf 'SetFileProperty %q %q %q\n' "${key%:*}" "${key##*:}" "${system_file_props[$key]}" >> "$config_save_target"
			done
		modified=y
	fi

	if [[ ${#config_only_file_props[@]} != 0 ]]
	then
		printf '\n\n# %s - Extra file properties\n\n\n' "$(date)" >> "$config_save_target"
		local key
		( Print0Array config_only_file_props | sort --zero-terminated ) | \
			while read -r -d $'\0' key
			do
				printf 'SetFileProperty %q %q %q\n' "${key%:*}" "${key##*:}" '' >> "$config_save_target"
			done
		modified=y
	fi

	LogLeave # Registering file properties

	if [[ $modified == n ]]
	then
		LogLeave 'Done (%s).\n' "$(Color G "configuration unchanged")"
	else
		LogLeave 'Done (%s).\n' "$(Color Y "configuration changed")"
	fi
}

: # include in coverage
