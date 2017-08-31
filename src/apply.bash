# apply.bash

# This file contains the implementation of aconfmgr's 'apply' command.

function AconfApply() {
	modified=n

	function PrintFileProperty() {
		local kind="$1"
		local value="$2"
		local file="$3"

		local value_text
		if [[ -z "$value" ]]
		then
			local default_value
			default_value="$(AconfDefaultFileProp "$file" "$kind")"
			value_text="$(printf "%s (default value)" "$(Color G "%s" "$default_value")")"
		else
			value_text="$(Color G "%s" "$value")"
		fi

		Log "Setting %s of %s to %s\n"	\
			"$(Color Y "%s" "$kind")"	\
			"$(Color C "%q" "$file")"	\
			"$value_text"
	}

	function ApplyFileProperty() {
		local kind="$1"
		local value="$2"
		local file="$3"

		PrintFileProperty "$kind" "$value" "$file"

		if [[ -z "$value" ]]
		then
			value="$(AconfDefaultFileProp "$file" "$kind")"
		fi

		case "$kind" in
			mode)
				sudo chmod "$value" "$file"
				;;
			owner)
				sudo chown --no-dereference "$value" "$file"
				;;
			group)
				sudo chgrp --no-dereference "$value" "$file"
				;;
			*)
				Log "Unknown property %s with value %s for file %s"	\
					"$(Color Y "%q" "$kind")"						\
					"$(Color G "%q" "$value")"						\
					"$(Color C "%q" "$file")"
				Exit 1
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

	function InstallFile() {
		local file="$1"
		local source="$output_dir"/files/"$file"

		sudo mkdir --parents "$(dirname "$file")"
		if [[ -h "$source" ]]
		then
			sudo cp --no-dereference "$source" "$file"
			sudo chown --no-dereference root:root "$file"
		elif [[ -d "$source" ]]
		then
			sudo install --mode=755 --owner=root --group=root -d "$file"
		else
			sudo install --mode=$default_file_mode --owner=root --group=root "$source" "$file"
		fi

		ApplyFileProps "$file"
	}

	AconfCompile

	LogEnter "Applying configuration...\n"

	#
	# Priority files
	#

	LogEnter "Installing priority files...\n"

	# These files must be installed before anything else,
	# because they affect or are required for what follows.
	local priority_files=(
		/etc/passwd
		/etc/group
		/etc/pacman.conf
		/etc/pacman.d/mirrorlist
		/etc/makepkg.conf
	)

	local file priority_file
	( Print0Array config_only_files ; Print0Array changed_files ) | \
		while read -r -d $'\0' file
		do
			for priority_file in "${priority_files[@]}"
			do
				if [[ "$file" == "$priority_file" ]]
				then
					LogEnter "Installing %s...\n" "$(Color C %q "$file")"
					Confirm ''
					InstallFile "$file"
					LogLeave
					break
				fi
			done
		done

	LogLeave # Installing priority files

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
	unknown_packages=($(comm -13																				\
							 <((PrintArray           packages ; PrintArray           foreign_packages) | sort)	\
							 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort)))

	if [[ ${#unknown_packages[@]} != 0 ]]
	then
		LogEnter "Unpinning %s unknown packages.\n" "$(Color G ${#unknown_packages[@]})"

		function Details() { Log "Unpinning (setting install reason to 'as dependency') the following packages:%s\n" "$(Color M " %q" "${unknown_packages[@]}")" ; }
		Confirm Details

		Print0Array unknown_packages | sudo xargs -0 "$PACMAN" --database --asdeps

		modified=y
		LogLeave
	fi

	# Missing packages (native and foreign packages that are listed in the configuration, but not marked as explicitly installed)
	missing_packages=($(comm -23																			\
							 <((PrintArray           packages ; PrintArray           foreign_packages) | sort)	\
							 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort)))

	# Missing installed/unpinned packages (native and foreign packages that are implicitly installed,
	# and listed in the configuration, but not marked as explicitly installed)
	missing_unpinned_packages=($(comm -12 <(PrintArray missing_packages) <("$PACMAN" --query --quiet | sort)))

	if [[ ${#missing_unpinned_packages[@]} != 0 ]]
	then
		LogEnter "Pinning %s unknown packages.\n" "$(Color G ${#missing_unpinned_packages[@]})"

		function Details() { Log "Pinning (setting install reason to 'explicitly installed') the following packages:%s\n" "$(Color M " %q" "${missing_unpinned_packages[@]}")" ; }
		Confirm Details

		Print0Array missing_unpinned_packages | sudo xargs -0 "$PACMAN" --database --asexplicit

		modified=y
		LogLeave
	fi


	# Missing native packages (native packages that are listed in the configuration, but not installed)
	missing_native_packages=($(comm -23 <(PrintArray packages) <("$PACMAN" --query --quiet | sort)))

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
	missing_foreign_packages=($(comm -23 <(PrintArray foreign_packages) <("$PACMAN" --query --quiet | sort)))

	if [[ ${#missing_foreign_packages[@]} != 0 ]]
	then
		LogEnter "Installing %s missing foreign packages.\n" "$(Color G ${#missing_foreign_packages[@]})"

		function Details() { Log "Installing the following foreign packages:%s\n" "$(Color M " %q" "${missing_foreign_packages[@]}")" ; }
		Confirm Details

		# If an AUR helper is present in the list of packages to be installed,
		# install it first, then use it to install the rest of the foreign packages.
		function InstallAurHelper() {
			local package helper
			for package in "${missing_foreign_packages[@]}"
			do
				for helper in "${aur_helpers[@]}"
				do
					if [[ "$package" == "$helper" ]]
					then
						LogEnter "Installing AUR helper %s...\n" "$(Color M %q "$helper")"
						ParanoidConfirm ''
						AconfInstallForeign "$package"
						aur_helper="$package"
						LogLeave
						return
					fi
				done
			done
		}
		if [[ $EUID != 0 ]]
		then
			InstallAurHelper
		fi

		AconfInstallForeign "${missing_foreign_packages[@]}"

		modified=y
		LogLeave
	fi

	# Orphan packages

	if "$PACMAN" --query --unrequired --unrequired --deps --quiet > /dev/null
	then
		LogEnter "Pruning orphan packages...\n"

		# We have to loop, since pacman's dependency scanning doesn't seem to be recursive
		iter=1
		while true
		do
			LogEnter "Iteration %s:\n" "$(Color G "$iter")"

			LogEnter "Querying orphan packages...\n"
			orphan_packages=($("$PACMAN" --query --unrequired --unrequired --deps --quiet || true))
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

	if [[ ${#config_only_files[@]} != 0 ]]
	then
		LogEnter "Installing %s new files.\n" "$(Color G ${#config_only_files[@]})"

		# shellcheck disable=2059
		function Details() {
			Log "Installing the following new files:\n"
			printf "$(Color W "*") $(Color C "%s" "%s")\n" "${config_only_files[@]}"
		}
		Confirm Details

		for file in "${config_only_files[@]}"
		do
			LogEnter "Installing %s...\n" "$(Color C "%q" "$file")"
			ParanoidConfirm ''
			InstallFile "$file"
			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	if [[ ${#changed_files[@]} != 0 ]]
	then
		LogEnter "Overwriting %s changed files.\n" "$(Color G ${#changed_files[@]})"

		# shellcheck disable=2059
		function Details() {
			Log "Overwriting the following changed files:\n"
			printf "$(Color W "*") $(Color C "%s" "%s")\n" "${changed_files[@]}"
		}
		Confirm Details

		for file in "${changed_files[@]}"
		do
			LogEnter "Overwriting %s...\n" "$(Color C "%q" "$file")"
			function Details() {
				AconfNeedProgram diff diffutils n
				"${diff_opts[@]}" --unified <(SuperCat "$file") "$output_dir"/files/"$file" || true
			}
			ParanoidConfirm Details
			InstallFile "$file"
			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	local -a files_to_delete=()
	local -a files_to_restore=()

	if [[ ${#system_only_files[@]} != 0 ]]
	then
		LogEnter "Processing system-only files...\n"

		# Delete unknown lost files (files not present in config and belonging to no package)

		LogEnter "Filtering system-only lost files...\n"
		tr '\n' '\0' < "$tmp_dir"/managed-files > "$tmp_dir"/managed-files-0
		local system_only_lost_files=0
		comm -13 --zero-terminated "$tmp_dir"/managed-files-0 <(Print0Array system_only_files) | \
			while read -r -d $'\0' file
			do
				files_to_delete+=("$file")
				system_only_lost_files=$((system_only_lost_files+1))
			done
		LogLeave "Done (%s system-only lost files).\n" "$(Color G %s $system_only_lost_files)"

		# Restore unknown managed files (files not present in config and belonging to a package)

		LogEnter "Filtering system-only managed files...\n"
		local system_only_managed_files=0
		comm -12 --zero-terminated "$tmp_dir"/managed-files-0 <(Print0Array system_only_files) | \
			while read -r -d $'\0' file
			do
				files_to_restore+=("$file")
				system_only_managed_files=$((system_only_managed_files+1))
			done
		LogLeave "Done (%s system-only managed files).\n" "$(Color G %s $system_only_managed_files)"

		LogLeave # Processing system-only files
	fi

	LogEnter "Processing deleted files...\n"

	if [[ ${#config_only_file_props[@]} != 0 ]]
	then

		for key in "${config_only_file_props[@]}"
		do
			if [[ "$key" == *:deleted ]]
			then
				local file="${key%:*}"
				files_to_delete+=("$file")
				unset "output_file_props[\$key]"
			fi
		done
	fi

	if [[ ${#system_only_file_props[@]} != 0 ]]
	then
		for key in "${system_only_file_props[@]}"
		do
			if [[ "$key" == *:deleted ]]
			then
				local file="${key%:*}"
				files_to_restore+=("$file")
				unset "system_file_props[\$key]"
			fi
		done
	fi

	LogLeave # Processing deleted files

	if [[ ${#files_to_delete[@]} != 0 ]]
	then
		LogEnter "Deleting %s files.\n" "$(Color G ${#files_to_delete[@]})"

		# shellcheck disable=2059
		function Details() {
			Log "Deleting the following files:\n"
			printf "$(Color W "*") $(Color C "%s" "%s")\n" "${files_to_delete[@]}"
		}
		Confirm Details

		# Iterate backwards, so that inner files/directories are
		# deleted before their parent ones.
		local i
		for (( i=${#files_to_delete[@]}-1 ; i >= 0 ; i-- ))
		do
			local file="${files_to_delete[$i]}"

			LogEnter "Deleting %s...\n" "$(Color C "%q" "$file")"
			ParanoidConfirm ''
			sudo rm --dir "$file"

			for prop in "${all_file_property_kinds[@]}"
			do
				local key="$file:$prop"
				unset "system_file_props[\$key]"
			done

			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	if [[ ${#files_to_restore[@]} != 0 ]]
	then
		LogEnter "Restoring %s files.\n" "$(Color G ${#files_to_restore[@]})"

		# shellcheck disable=2059
		function Details() {
			Log "Restoring the following files:\n"
			printf "$(Color W "*") $(Color C "%s" "%s")\n" "${files_to_restore[@]}"
		}
		Confirm Details

		for file in "${files_to_restore[@]}"
		do
			local package

			# Ensure file exists, to work around pacman's inability to
			# query ownership of non-existing files. See:
			# https://lists.archlinux.org/pipermail/pacman-dev/2017-August/022107.html
			local absent=false
			if ! sudo stat "$file" > /dev/null
			then
				Log "Temporarily creating file %s for package query...\n" "$(Color C "%q" "$file")"
				sudo touch "$file"
				absent=true
			fi

			package="$("$PACMAN" --query --owns --quiet "$file" | head -n 1 || true)"

			if $absent
			then
				sudo rm "$file"
			fi

			if [[ -z "$package" ]]
			then
				Log "Can't find owner of file %s\n" "$(Color C "%q" "$file")"
				Exit 1
			fi

			LogEnter "Restoring %s file %s...\n" "$(Color M "%q" "$package")" "$(Color C "%q" "$file")"
			function Details() {
				AconfNeedProgram diff diffutils n
				AconfGetPackageOriginalFile "$package" "$file" | ( "${diff_opts[@]}" --unified <(SuperCat "$file") - || true )
			}
			ParanoidConfirm Details

			local package_file
			package_file="$(AconfNeedPackageFile "$package")"

			# If we are restoring a directory, it may be non-empty.
			# Extract the object to a temporary location first.
			local tmp_base=${tmp_dir:?}/dir-props
			sudo rm -rf "$tmp_base"

			mkdir -p "$tmp_base"
			local tmp_file="$tmp_base""$file"
			sudo tar x --directory "$tmp_base" --file "$package_file" --no-recursion "${file/\//}"

			AconfReplace "$tmp_file" "$file"
			sudo rm -rf "$tmp_base"

			LogLeave ''
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
