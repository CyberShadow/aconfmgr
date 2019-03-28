# apply.bash

# This file contains the implementation of aconfmgr's 'apply' command.

function AconfApply() {
	local modified=n

	function PrintFileProperty() {
		local kind="$1"
		local value="$2"
		local file="$3"

		local value_text
		if [[ -z "$value" ]]
		then
			local default_value
			default_value="$(AconfDefaultFileProp "$file" "$kind")"
			value_text="$(printf '%s (default value)' "$(Color G "%s" "$default_value")")"
		else
			value_text="$(Color G "%s" "$value")"
		fi

		Log 'Setting %s of %s to %s\n'	\
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
				Log 'Unknown property %s with value %s for file %s'	\
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
			if [[ -n "${output_file_props[$key]+x}" ]]
			then
				local value="${output_file_props[$key]}"
				ApplyFileProperty "$prop" "$value" "$file"
				unset "output_file_props[\$key]"
				unset "system_file_props[\$key]"

				printf '%s\t%s\t%q\n' "$prop" "$value" "$file" >> "$system_dir"/file-props.txt
			fi
		done
	}

	function InstallFile() {
		local file="$1"
		local source="$output_dir"/files/"$file"

		# system

		if ! ( test -d "$source" && sudo test -d "$file" )
		then
			sudo rm --force --dir "$file"
		fi

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

		# $system_dir

		local system_file="$system_dir"/files/"$file"
		if ! ( test -d "$source" && sudo test -d "$system_file" )
		then
			rm --force --dir "$system_file"
		fi

		mkdir --parents "$(dirname "$system_file")"
		if [[ -h "$source" ]]
		then
			cp --no-dereference "$source" "$system_file"
		elif [[ -d "$source" ]]
		then
			mkdir --parents "$system_file"
		else
			cp --no-dereference "$source" "$system_file"
		fi

		ApplyFileProps "$file"

		if [[ -h "$source" ]]
		then
			# ApplyFileProps will apply and unset owner/group. For
			# symlinks, we need to avoid attempting to restore the
			# mode, so unset it here.
			unset "system_file_props[\$file:mode]"
			printf '%s\t%s\t%q\n' mode '' "$file" >> "$system_dir"/file-props.txt
		fi
	}

	AconfCompile

	LogEnter 'Applying configuration...\n'

	#
	# Priority files
	#

	LogEnter 'Installing priority files...\n'

	function Details_DiffFile() {
		if sudo test -d "$file"
		then
			Log '%s (old) is a directory.\n' "$(Color C "%q" "$file")"
		elif test -d "$output_dir"/files/"$file"
		then
			Log '%s (new) is a directory.\n' "$(Color C "%q" "$file")"
		else
			AconfNeedProgram diff diffutils n
			sudo "${diff_opts[@]}" --unified --no-dereference --report-identical-files "$file" "$output_dir"/files/"$file" || true
		fi
	}

	local file
	comm -12 --zero-terminated \
		 <(  Print0Array priority_files                                 | sort --zero-terminated ) \
		 <( (Print0Array config_only_files ; Print0Array changed_files) | sort --zero-terminated ) | \
		while read -r -d $'\0' file
		do
			LogEnter 'Installing %s...\n' "$(Color C %q "$file")"

			if sudo test -e "$file"
			then
				Confirm Details_DiffFile
			else
				Confirm ''
			fi

			InstallFile "$file"
			LogLeave
			modified=y
		done
	comm -23 --zero-terminated <(Print0Array config_only_files | sort --zero-terminated) <(Print0Array priority_files | sort --zero-terminated) | mapfile -d $'\0' config_only_files
	comm -23 --zero-terminated <(Print0Array changed_files     | sort --zero-terminated) <(Print0Array priority_files | sort --zero-terminated) | mapfile -d $'\0' changed_files

	LogLeave # Installing priority files

	#
	# Apply packages
	#

	LogEnter 'Configuring packages...\n'

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
	local -a unknown_packages
	comm -13                                                                               \
		 <((PrintArray           packages ; PrintArray           foreign_packages) | sort) \
		 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort) \
		 | mapfile -t unknown_packages

	if [[ ${#unknown_packages[@]} != 0 ]]
	then
		LogEnter 'Unpinning %s unknown packages.\n' "$(Color G ${#unknown_packages[@]})"

		function Details() { Log 'Unpinning (setting install reason to '\''as dependency'\'') the following packages:%s\n' "$(Color M " %q" "${unknown_packages[@]}")" ; }
		Confirm Details

		Print0Array unknown_packages | sudo xargs -0 "$PACMAN" --database --asdeps

		modified=y
		LogLeave
	fi

	# Missing packages (native and foreign packages that are listed in the configuration, but not marked as explicitly installed)
	local -a missing_packages
	comm -23																			   \
		 <((PrintArray           packages ; PrintArray           foreign_packages) | sort) \
		 <((PrintArray installed_packages ; PrintArray installed_foreign_packages) | sort) \
		 | mapfile -t missing_packages

	# Missing installed/unpinned packages (native and foreign packages that are implicitly installed,
	# and listed in the configuration, but not marked as explicitly installed)
	local -a missing_unpinned_packages
	comm -12 <(PrintArray missing_packages) <(("$PACMAN" --query --quiet || true) | sort) | mapfile -t missing_unpinned_packages

	if [[ ${#missing_unpinned_packages[@]} != 0 ]]
	then
		LogEnter 'Pinning %s unknown packages.\n' "$(Color G ${#missing_unpinned_packages[@]})"

		function Details() { Log 'Pinning (setting install reason to '\''explicitly installed'\'') the following packages:%s\n' "$(Color M " %q" "${missing_unpinned_packages[@]}")" ; }
		Confirm Details

		Print0Array missing_unpinned_packages | sudo xargs -0 "$PACMAN" --database --asexplicit

		modified=y
		LogLeave
	fi


	# Missing native packages (native packages that are listed in the configuration, but not installed)
	local -a missing_native_packages
	comm -23 <(PrintArray packages) <(("$PACMAN" --query --quiet || true) | sort) | mapfile -t missing_native_packages

	if [[ ${#missing_native_packages[@]} != 0 ]]
	then
		LogEnter 'Installing %s missing native packages.\n' "$(Color G ${#missing_native_packages[@]})"

		function Details() { Log 'Installing the following native packages:%s\n' "$(Color M " %q" "${missing_native_packages[@]}")" ; }
		ParanoidConfirm Details

		AconfInstallNative "${missing_native_packages[@]}"

		modified=y
		LogLeave
	fi

	# Missing foreign packages (foreign packages that are listed in the configuration, but not installed)
	local -a missing_foreign_packages
	comm -23 <(PrintArray foreign_packages) <(("$PACMAN" --query --quiet || true) | sort) | mapfile -t missing_foreign_packages

	if [[ ${#missing_foreign_packages[@]} != 0 ]]
	then
		LogEnter 'Installing %s missing foreign packages.\n' "$(Color G ${#missing_foreign_packages[@]})"

		function Details() { Log 'Installing the following foreign packages:%s\n' "$(Color M " %q" "${missing_foreign_packages[@]}")" ; }
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
						LogEnter 'Installing AUR helper %s...\n' "$(Color M %q "$helper")"
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

	local -a files_in_deleted_packages=()

	if "$PACMAN" --query --unrequired --unrequired --deps --quiet > /dev/null
	then
		LogEnter 'Pruning orphan packages...\n'

		# We have to loop, since pacman's dependency scanning doesn't seem to be recursive
		local iter=1
		while true
		do
			LogEnter 'Iteration %s:\n' "$(Color G "$iter")"

			LogEnter 'Querying orphan packages...\n'
			local -a orphan_packages
			( "$PACMAN" --query --unrequired --unrequired --deps --quiet || true ) | mapfile -t orphan_packages
			LogLeave

			if [[ ${#orphan_packages[@]} != 0 ]]
			then
				LogEnter 'Pruning %s orphan packages.\n' "$(Color G ${#orphan_packages[@]})"

				function Details() { Log 'Removing the following orphan packages:%s\n' "$(Color M " %q" "${orphan_packages[@]}")" ; }
				ParanoidConfirm Details

				local -a deleted_files=()
				"$PACMAN" --query --list --quiet "${orphan_packages[@]}" | sed 's#^\(.*\)/$#\1#' | mapfile -t deleted_files
				files_in_deleted_packages+=("${deleted_files[@]}")

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

	# Read file owners
	local -a modified_files_in_deleted_packages
	(
		cat "$tmp_dir"/output-files "$tmp_dir"/system-files
		local kind value file
		cat "$output_dir"/file-props.txt "$system_dir"/file-props.txt \
			| \
			while IFS=$'\t' read -r kind value file
			do
				eval "printf '%s\\0' $file" # Unescape
			done
	) \
		| sort --zero-terminated --unique \
		| comm --zero-terminated -12 <(Print0Array files_in_deleted_packages | sort --zero-terminated --unique) /dev/stdin \
		| tac \
		| mapfile -t -d $'\0' modified_files_in_deleted_packages

	if [[ "${#modified_files_in_deleted_packages[@]}" -gt 0 ]]
	then
		LogEnter 'Detected %s modified files in pruned packages.\n' \
				 "$(Color G %s "${#modified_files_in_deleted_packages[@]}")"

		LogEnter 'Updating system files...\n'
		local file
		for file in "${modified_files_in_deleted_packages[@]}"
		do
			local system_file="$system_dir"/files"$file"
			if [[ -h "$system_file" || -f "$system_file" ]]
			then
				rm --force "$system_file"
			elif [[ -d "$system_file" ]]
			then
				rmdir --ignore-fail-on-non-empty "$system_file"
			elif [[ -e "$system_file" ]]
			then
				FatalError '%s exists, but is neither file or directory or link?\n' \
						   "$(Color C "%q" "$file")"
			fi

			local prop
			for prop in "${all_file_property_kinds[@]}"
			do
				printf '%s\t%s\t%q\n' "$prop" '' "$file" >> "$system_dir"/file-props.txt
			done
		done
		LogLeave

		LogEnter 'Rescanning...\n'
		AconfAnalyzeFiles
		LogLeave
		LogLeave
	fi

	#
	# Copy files
	#

	LogEnter 'Configuring files...\n'

	if [[ ${#config_only_files[@]} != 0 ]]
	then
		LogEnter 'Installing %s new files.\n' "$(Color G ${#config_only_files[@]})"

		# shellcheck disable=2059
		function Details() {
			Log 'Installing the following new files:\n'
			printf "$(Color W "*") $(Color C "%s" "%s")\\n" "${config_only_files[@]}"
		}
		Confirm Details

		for file in "${config_only_files[@]}"
		do
			LogEnter 'Installing %s...\n' "$(Color C "%q" "$file")"
			ParanoidConfirm ''
			InstallFile "$file"
			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	if [[ ${#changed_files[@]} != 0 ]]
	then
		LogEnter 'Overwriting %s changed files.\n' "$(Color G ${#changed_files[@]})"

		# shellcheck disable=2059
		function Details() {
			Log 'Overwriting the following changed files:\n'
			printf "$(Color W "*") $(Color C "%s" "%s")\\n" "${changed_files[@]}"
		}
		Confirm Details

		for file in "${changed_files[@]}"
		do
			LogEnter 'Overwriting %s...\n' "$(Color C "%q" "$file")"
			ParanoidConfirm Details_DiffFile
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
		LogEnter 'Processing system-only files...\n'

		# Delete unknown lost files (files not present in config and belonging to no package)

		LogEnter 'Filtering system-only lost files...\n'
		local system_only_lost_files=0
		tr '\n' '\0' < "$tmp_dir"/managed-files > "$tmp_dir"/managed-files-0
		comm -13 --zero-terminated "$tmp_dir"/managed-files-0 <(Print0Array system_only_files) | \
			while read -r -d $'\0' file
			do
				files_to_delete+=("$file")
				system_only_lost_files=$((system_only_lost_files+1))
			done
		LogLeave 'Done (%s system-only lost files).\n' "$(Color G %s $system_only_lost_files)"

		# Restore unknown managed files (files not present in config and belonging to a package)

		LogEnter 'Filtering system-only managed files...\n'
		local system_only_managed_files=0
		comm -12 --zero-terminated "$tmp_dir"/managed-files-0 <(Print0Array system_only_files) | \
			while read -r -d $'\0' file
			do
				if [[ "${output_file_props[$file:deleted]:-}" == y ]]
				then
					continue # Don't restore files that the user wants deleted
				fi

				files_to_restore+=("$file")
				system_only_managed_files=$((system_only_managed_files+1))
			done
		LogLeave 'Done (%s system-only managed files).\n' "$(Color G %s $system_only_managed_files)"

		LogLeave # Processing system-only files
	fi

	LogEnter 'Processing deleted files...\n'

	if [[ ${#config_only_file_props[@]} != 0 ]]
	then
		local key
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
		local key
		for key in "${system_only_file_props[@]}"
		do
			if [[ "$key" == *:deleted ]]
			then
				local file="${key%:*}"

				if [[ -h "$output_dir"/files/"$file" || -e "$output_dir"/files/"$file" ]]
				then
					# If we are going to replace a deleted file with
					# one from the configuration, do not attempt to
					# restore it.
					:
				else
					files_to_restore+=("$file")
				fi

				unset "system_file_props[\$key]"
			fi
		done
	fi

	LogLeave # Processing deleted files

	if [[ ${#files_to_delete[@]} != 0 ]]
	then
		LogEnter 'Deleting %s files.\n' "$(Color G ${#files_to_delete[@]})"
		printf '%s\0' "${files_to_delete[@]}" | sort --zero-terminated | mapfile -d $'\0' files_to_delete

		# shellcheck disable=2059
		function Details() {
			Log 'Deleting the following files:\n'
			printf "$(Color W "*") $(Color C "%s" "%s")\\n" "${files_to_delete[@]}"
		}
		Confirm Details

		local -A parents=()

		# Iterate backwards, so that inner files/directories are
		# deleted before their parent ones.
		local i
		for (( i=${#files_to_delete[@]}-1 ; i >= 0 ; i-- ))
		do
			local file="${files_to_delete[$i]}"

			if [[ -n "${parents[$file]+x}" && -n "$(sudo find "$file" -maxdepth 0 -type d -not -empty 2>/dev/null)" ]]
			then
				# Ignoring paths under a directory can cause us to
				# want to remove a directory which will in fact not be
				# empty, and actually contain ignored files. So, skip
				# deleting empty directories which are parents of
				# previously-deleted objects.
				LogEnter 'Skipping non-empty directory %s.\n' "$(Color C "%q" "$file")"
			else
				LogEnter 'Deleting %s...\n' "$(Color C "%q" "$file")"
				ParanoidConfirm ''
				sudo rm --dir "$file"
			fi

			local prop
			for prop in "${all_file_property_kinds[@]}"
			do
				local key="$file:$prop"
				unset "system_file_props[\$key]"
			done

			parents["$(dirname "$file")"]=y

			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	if [[ ${#files_to_restore[@]} != 0 ]]
	then
		LogEnter 'Restoring %s files.\n' "$(Color G ${#files_to_restore[@]})"
		printf '%s\0' "${files_to_restore[@]}" | sort --zero-terminated | mapfile -d $'\0' files_to_restore

		# shellcheck disable=2059
		function Details() {
			Log 'Restoring the following files:\n'
			printf "$(Color W "*") $(Color C "%s" "%s")\\n" "${files_to_restore[@]}"
		}
		Confirm Details

		# Read file owners
		local -A file_owners
		local file
		while read -r -d $'\0' file
		do
			local package
			read -r -d $'\0' package
			file_owners[$file]=$package
		done < "$tmp_dir"/file-owners

		for file in "${files_to_restore[@]}"
		do
			local package

			if [[ -n "${file_owners[$file]+x}" ]]
			then
				package=${file_owners[$file]}
			else
				package="$( ("$PACMAN" --query --owns --quiet "$file" || true) | head -n 1)"

				if [[ -z "$package" ]]
				then
					Log 'Can'\''t find package owning file %s\n' "$(Color C "%q" "$file")"
					Exit 1
				fi
			fi

			LogEnter 'Restoring %s file %s...\n' "$(Color M "%q" "$package")" "$(Color C "%q" "$file")"
			function Details() {
				AconfNeedProgram diff diffutils n
				AconfGetPackageOriginalFile "$package" "$file" | ( "${diff_opts[@]}" --unified <(SuperCat "$file") - || true )
			}
			if sudo test -f "$file"
			then
				ParanoidConfirm Details
			else
				ParanoidConfirm ''
			fi

			AconfRestoreFile "$package" "$file"

			# The file was restored with all of its original properties.
			local prop
			for prop in owner group mode
			do
				unset "system_file_props[\$file:\$prop]"
			done

			LogLeave ''
		done

		modified=y
		LogLeave
	fi

	#
	# Apply remaining file properties
	#

	LogEnter 'Configuring file properties...\n'

	AconfCompareFileProps # Update data after ApplyFileProps' unsets

	if [[ ${#config_only_file_props[@]} != 0 || ${#changed_file_props[@]} != 0 || ${#system_only_file_props[@]} != 0 ]]
	then
		LogEnter 'Found %s new, %s changed, and %s extra files properties.\n'	\
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
					LogEnter '%s the following file properties:\n' "$verb"
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

		local key
		( Print0Array config_only_file_props ; Print0Array changed_file_props ; Print0Array system_only_file_props ) | \
			while read -r -d $'\0' key
			do
				local kind="${key##*:}"
				local file="${key%:*}"
				local value="${output_file_props[$key]:-}"

				ApplyFileProperty "$kind" "$value" "$file"
			done

		modified=y
		LogLeave
	fi

	LogLeave # Configuring file properties

	LogLeave # Configuring files

	if [[ $modified == n ]]
	then
		LogLeave 'Done (%s).\n' "$(Color G "system state unchanged")"
	else
		LogLeave 'Done (%s).\n' "$(Color Y "system state changed")"
	fi
}

: # include in coverage
