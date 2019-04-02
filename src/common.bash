# common.bash

# This file contains aconfmgr's common code, used by all commands.

####################################################################################################

# Globals

PACMAN=${PACMAN:-pacman}

output_dir="$tmp_dir"/output
system_dir="$tmp_dir"/system # Current system configuration, to be compared against the output directory

default_file_mode=644

ANSI_clear_line="[0K"
ANSI_color_R="[1;31m"
ANSI_color_G="[1;32m"
ANSI_color_Y="[1;33m"
ANSI_color_B="[1;34m"
ANSI_color_M="[1;35m"
ANSI_color_C="[1;36m"
ANSI_color_W="[1;39m"
ANSI_reset="[0m"

verbose=0
lint_config=false
declare -i config_warnings=0

umask $((666 - default_file_mode))

####################################################################################################

# Defaults

# Initial ignore path list.
# Can be appended to using the IgnorePath helper.
ignore_paths=(
    '/dev'
    '/home'
    '/media'
    '/mnt'
    '/proc'
    '/root'
    '/run'
    '/sys'
    '/tmp'
    # '/var/.updated'
    '/var/cache'
    # '/var/lib'
    # '/var/lock'
    # '/var/log'
    # '/var/spool'
)

# These files must be installed before anything else,
# because they affect or are required for what follows.
# shellcheck disable=SC2034
priority_files=(
	/etc/passwd
	/etc/group
	/etc/pacman.conf
	/etc/pacman.d/mirrorlist
	/etc/makepkg.conf
)

# Some limits for common-sense warnings.
# Feel free to override these in your configuration.
warn_size_threshold=$((10*1024*1024)) # Warn on copying files bigger than this
warn_file_count_threshold=1000        # Warn on finding this many lost files
warn_tmp_df_threshold=$((1024*1024))  # Warn on error if free space in $tmp_dir is below this

####################################################################################################

function LogLeaveDirStats() {
	local dir="$1"
	Log 'Finalizing...\r'
	LogLeave 'Done (%s native packages, %s foreign packages, %s files).\n'	\
			 "$(Color G "$(wc -l < "$dir"/packages.txt)")"					\
			 "$(Color G "$(wc -l < "$dir"/foreign-packages.txt)")"			\
			 "$(Color G "$(find "$dir"/files -not -type d | wc -l)")"
}

# Run user configuration scripts, to collect desired state into #output_dir
function AconfCompileOutput() {
	LogEnter 'Compiling user configuration...\n'

	rm -rf "$output_dir"
	mkdir --parents "$output_dir"
	mkdir "$output_dir"/files
	touch "$output_dir"/packages.txt
	touch "$output_dir"/foreign-packages.txt
	touch "$output_dir"/file-props.txt
	mkdir --parents "$config_dir"

	# Configuration

	Log 'Using configuration in %s\n' "$(Color C "%q" "$config_dir")"

	typeset -ag ignore_packages=()
	typeset -ag ignore_foreign_packages=()
	typeset -Ag used_files

	local found=n
	local file
	for file in "$config_dir"/*.sh
	do
		if [[ -e "$file" ]]
		then
			LogEnter 'Sourcing %s...\n' "$(Color C "%q" "$file")"
			# shellcheck source=/dev/null
			source "$file"
			found=y
			LogLeave ''
		fi
	done

	if $lint_config
	then
		# Check for unused files (files not referenced by the CopyFile
		# helper).
		# Only do this in the "check" action, as unused files do not
		# necessarily indicate a bug in the configuration - they may
		# simply be used under certain conditions.
		if [[ -d "$config_dir/files" ]]
		then
			local line
			find "$config_dir/files" -type f -print0 | \
				while read -r -d $'\0' line
				do
					local key=${line#$config_dir/files}
					if [[ -z "${used_files[$key]+x}" ]]
					then
						Log '%s: Unused file: %s\n' \
							"$(Color Y "Warning")" \
							"$(Color C "%q" "$line")"
						config_warnings+=1
					fi
				done
		fi
	fi

	if [[ $found == y ]]
	then
		LogLeaveDirStats "$output_dir"
	else
		LogLeave 'Done (configuration not found).\n'
	fi
}

skip_inspection=n

# Collect system state into $system_dir
function AconfCompileSystem() {
	LogEnter 'Inspecting system state...\n'

	if [[ $skip_inspection == y ]]
	then
		LogLeave 'Skipped.\n'
		return
	fi

	rm -rf "$system_dir"
	mkdir --parents "$system_dir"
	mkdir "$system_dir"/files
	touch "$system_dir"/file-props.txt
	touch "$system_dir"/orig-file-props.txt

	### Packages

	LogEnter 'Querying package list...\n'
	( "$PACMAN" --query --quiet --explicit --native  || true ) | sort | ( grep -vFxf <(PrintArray ignore_packages        ) || true ) > "$system_dir"/packages.txt
	( "$PACMAN" --query --quiet --explicit --foreign || true ) | sort | ( grep -vFxf <(PrintArray ignore_foreign_packages) || true ) > "$system_dir"/foreign-packages.txt
	LogLeave

	### Files

	local -a found_files
	found_files=()

	# whether the contents is different from the original
	local -A found_file_edited
	found_file_edited=()

	# Lost files

	local ignore_args=()
	local ignore_path
	for ignore_path in "${ignore_paths[@]}"
	do
		ignore_args+=(-wholename "$ignore_path" -o)
	done

	LogEnter 'Enumerating managed files...\n'
	mkdir --parents "$tmp_dir"
	( "$PACMAN" --query --list --quiet || true ) | sed 's#\/$##' | sort --unique > "$tmp_dir"/managed-files
	LogLeave

	LogEnter 'Searching for lost files...\n'

	local line
	local -Ag ignored_dirs

	# Progress display - only show file names once per second
	local progress_fd
	exec {progress_fd}> \
		 >( gawk '
BEGIN {
    RS = "\0";
    t = systime();
};
{
    u = systime();
    if (t != u) {
        t = u;
        printf "%s\0", $0;
        system(""); # https://unix.stackexchange.com/a/83853/4830
	}
}' | \
				while read -r -d $'\0' line
				do
					local path=${line:1}
					path=${path%/*} # Never show files, only directories
					while [[ ${#path} -gt 40 ]]
					do
						path=${path%/*}
					done
					Log 'Scanning %s...\r' "$(Color M "%q" "$path")"
				done
		  )

	local lost_file_count=0
	(
		sudo find /									\
			 -not									\
			 \(										\
			 	\(									\
					"${ignore_args[@]}"				\
					-false							\
				\)									\
				-printf 'I' -print0 -prune			\
			\)										\
			-printf 'O' -print0						\
			| tee /dev/fd/$progress_fd				\
			| ( grep								\
					--null --null-data				\
					--invert-match					\
					--fixed-strings					\
					--line-regexp					\
					--file							\
					<( < "$tmp_dir"/managed-files	\
						 sed -e 's#^#O#'			\
					 )								\
					|| true )						\
	) |												\
		while read -r -d $'\0' line
		do
			local file action
			file=${line:1}
			action=${line:0:1}

			case "$action" in
				O) # Lost file
					#echo "ignore_paths+='$file' # "
					if ((verbose))
					then
						Log '%s\r' "$(Color C "%q" "$file")"
					fi

					found_files+=("$file")
					found_file_edited[$file]=y
					lost_file_count=$((lost_file_count+1))

					if [[ $lost_file_count -eq $warn_file_count_threshold ]]
					then
						LogEnter '%s: reached %s lost files while in directory %s.\n' \
							"$(Color Y "Warning")" \
							"$(Color G "$lost_file_count")" \
							"$(Color C "%q" "$(dirname "$file")")"
						LogLeave 'Perhaps add %s (or a parent directory) to configuration to ignore it.\n' \
							"$(Color Y "IgnorePath %q" "$(dirname "$file")"/'*')"
					fi
					;;
				I) # Ignored

					# For convenience, we want to also ignore
					# directories which contain only ignored files.
					#
					# This is so that a rule such as:
					#
					# IgnorePath '/foo/bar/baz/*.log'
					#
					# does not cause `aconfmgr save` to still emit lines like
					#
					# CreateDir /foo/bar
					# CreateDir /foo/bar/baz
					#
					# However, we can't simply exclude parent dirs of
					# excluded files from the file list, as then they
					# will show up as missing in the diff against the
					# compiled configuration. So, later we remove
					# parent directories of any found un-ignored
					# files.

					local path="$file"
					while [[ -n "$path" ]]
					do
						ignored_dirs[$path]=y
						path=${path%/*}
					done
					;;
			esac
		done

	LogLeave 'Done (%s lost files).\n' "$(Color G %s $lost_file_count)"

	exec {progress_fd}<&-

	LogEnter 'Cleaning up ignored files'\'' directories...\n'

	local file
	for file in "${found_files[@]}"
	do
		if [[ -z "${ignored_dirs[$file]+x}" ]]
		then
			local path="$file"
			while [[ -n "$path" ]]
			do
				unset "ignored_dirs[\$path]"
				path=${path%/*}
			done
		fi
	done

	LogLeave

	# Modified files

	LogEnter 'Searching for modified files...\n'

	AconfNeedProgram paccheck pacutils n
	local modified_file_count=0
	local -A saw_file

	# Tentative tracking of original file properties.
	# The canonical version is read from orig-file-props.txt in AconfAnalyzeFiles
	unset orig_file_props ; typeset -Ag orig_file_props

	touch "$tmp_dir"/file-owners

	sudo sh -c "LC_ALL=C stdbuf -o0 paccheck --md5sum --files --file-properties --backup --noupgrade 2>&1 || true" | \
		while read -r line
		do
			if [[ $line =~ ^(.*):\ \'(.*)\'\ (type|size|modification\ time|md5sum|UID|GID|permission|symlink\ target)\ mismatch\ \(expected\ (.*)\)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				local kind="${BASH_REMATCH[3]}"
				local value="${BASH_REMATCH[4]}"

				local ignored=n
				for ignore_path in "${ignore_paths[@]}"
				do
					# shellcheck disable=SC2053
					if [[ "$file" == $ignore_path ]]
					then
						ignored=y
						break
					fi
				done

				if [[ $ignored == n ]]
				then
					if [[ -z "${saw_file[$file]+x}" ]]
					then
						saw_file[$file]=y
						Log '%s: %s\n' "$(Color M "%q" "$package")" "$(Color C "%q" "$file")"
						found_files+=("$file")
						modified_file_count=$((modified_file_count+1))
					fi

					local prop
					case "$kind" in
						UID)
							prop=owner
							value=${value#*/}
							;;
						GID)
							prop=group
							value=${value#*/}
							;;
						permission)
							prop=mode
							;;
						type|size|modification\ time|md5sum|symlink\ target)
							prop=
							found_file_edited[$file]=y
							;;
						*)
							prop=
							;;
					esac

					if [[ -n "$prop" ]]
					then
						local key="$file:$prop"
						orig_file_props[$key]=$value

						printf '%s\t%s\t%q\n' "$prop" "$value" "$file" >> "$system_dir"/orig-file-props.txt
					fi
				fi
				printf '%s\0%s\0' "$file" "$package" >> "$tmp_dir"/file-owners
			elif [[ $line =~ ^(.*):\ \'(.*)\'\ missing\ file$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				Log '%s (missing)...\r' "$(Color M "%q" "$package")"
				printf '%s\t%s\t%q\n' "deleted" "y" "$file" >> "$system_dir"/file-props.txt
				printf '%s\0%s\0' "$file" "$package" >> "$tmp_dir"/file-owners
			elif [[ $line =~ ^warning:\ (.*):\ \'(.*)\'\ read\ error\ \(No\ such\ file\ or\ directory\)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				# Ignore
			elif [[ $line =~ ^(.*):\ all\ files\ match\ (database|mtree|mtree\ md5sums)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				Log '%s...\r' "$(Color M "%q" "$package")"
				#echo "Now at ${BASH_REMATCH[1]}"
			else
				Log 'Unknown paccheck output line: %s\n' "$(Color Y "%q" "$line")"
			fi
		done
	LogLeave 'Done (%s modified files).\n' "$(Color G %s $modified_file_count)"

	LogEnter 'Reading file attributes...\n'

	typeset -a found_file_types found_file_sizes found_file_modes found_file_owners found_file_groups
	if [[ ${#found_files[*]} == 0 ]]
	then
		Log 'No files found, skipping.\n'
	else
		Log 'Reading file types...\n'  ; Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%F | mapfile -t  found_file_types
		Log 'Reading file sizes...\n'  ; Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%s | mapfile -t  found_file_sizes
		Log 'Reading file modes...\n'  ; Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%a | mapfile -t  found_file_modes
		Log 'Reading file owners...\n' ; Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%U | mapfile -t found_file_owners
		Log 'Reading file groups...\n' ; Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%G | mapfile -t found_file_groups
	fi

	LogLeave # Reading file attributes

	LogEnter 'Processing found files...\n'

	local i
	for ((i=0; i<${#found_files[*]}; i++))
	do
		Log '%s/%s...\r' "$(Color G "$i")" "$(Color G "${#found_files[*]}")"

		local  file="${found_files[$i]}"
		local  type="${found_file_types[$i]}"
		local  size="${found_file_sizes[$i]}"
		local  mode="${found_file_modes[$i]}"
		local owner="${found_file_owners[$i]}"
		local group="${found_file_groups[$i]}"

		if [[ "${ignored_dirs[$file]-n}" == y ]]
		then
			continue
		fi

		if [[ -n "${found_file_edited[$file]+x}" ]]
		then
			mkdir --parents "$(dirname "$system_dir"/files/"$file")"
			if [[ "$type" == "symbolic link" ]]
			then
				ln -s "$(sudo readlink "$file")" "$system_dir"/files/"$file"
			elif [[ "$type" == "regular file" || "$type" == "regular empty file" ]]
			then
				if [[ $size -gt $warn_size_threshold ]]
				then
					Log '%s: copying large file %s (%s bytes). Add %s to configuration to ignore.\n' "$(Color Y "Warning")" "$(Color C "%q" "$file")" "$(Color G "$size")" "$(Color Y "IgnorePath %q" "$file")"
				fi
				( sudo cat "$file" ) > "$system_dir"/files/"$file"
			elif [[ "$type" == "directory" ]]
			then
				mkdir --parents "$system_dir"/files/"$file"
			else
				Log '%s: Skipping file %s with unknown type %s. Add to %s to ignore.\n' "$(Color Y "Warning")" "$(Color C "%q" "$file")" "$(Color G "$type")" "$(Color Y "ignore_paths")"
				continue
			fi
		fi

		{
			local prop
			for prop in mode owner group
			do
				# Ignore mode "changes" in symbolic links
				# If a file's type changes, a change in mode can be reported too.
				# But, symbolic links cannot have a mode, so ignore this change.
				if [[ "$type" == "symbolic link" && "$prop" == mode ]]
				then
					continue
				fi

				local value
				eval "value=\$$prop"

				local default_value

				if [[ $i -lt $lost_file_count ]]
				then
					# For lost files, the default owner/group is root/root,
					# and the default mode depends on the type.
					# Let AconfDefaultFileProp get the correct default value for us.

					default_value=
				else
					# For owned files, we assume that the defaults are the
					# files' current properties, unless paccheck said
					# otherwise.

					default_value=$value
				fi

				local orig_value
				orig_value=$(AconfDefaultFileProp "$file" "$prop" "$type" "$default_value")

				[[ "$value" == "$orig_value" ]] || printf '%s\t%s\t%q\n' "$prop" "$value" "$file"
			done
		} >> "$system_dir"/file-props.txt
	done

	LogLeave # Processing found files

	LogLeaveDirStats "$system_dir" # Inspecting system state
}

####################################################################################################

typeset -A file_property_kind_exists

# Print to stdout the original/default value of the given file property.
# Uses orig_file_props entry if present.
function AconfDefaultFileProp() {
	local file=$1 # Absolute path to the file
	local prop=$2 # Name of the property (owner, group, or mode)
	local type="${3:-}" # Type of the file, as identified by `stat --format=%F`
	local default="${4:-}" # Default value, returned if we don't know the original file property.

	local key="$file:$prop"

	if [[ -n "${orig_file_props[$key]+x}" ]]
	then
		printf '%s' "${orig_file_props[$key]}"
		return
	fi

	if [[ -n "$default" ]]
	then
		printf '%s' "$default"
		return
	fi

	case "$prop" in
		mode)
			if [[ -z "$type" ]]
			then
				type=$(sudo env LC_ALL=C stat --format=%F "$file")
			fi

			if [[ "$type" == "symbolic link" ]]
			then
				FatalError 'Symbolic links do not have a mode\n' # Bug
			elif [[ "$type" == "directory" ]]
			then
				printf 755
			else
				printf '%s' "$default_file_mode"
			fi
			;;
		owner|group)
			printf 'root'
			;;
	esac
}

# Read a file-props.txt file into an associative array.
function AconfReadFileProps() {
	local filename="$1" # Path to file-props.txt to be read
	local varname="$2"  # Name of global associative array variable to read into

	local line
	while read -r line
	do
		if [[ $line =~ ^(.*)\	(.*)\	(.*)$ ]]
		then
			local kind="${BASH_REMATCH[1]}"
			local value="${BASH_REMATCH[2]}"
			local file="${BASH_REMATCH[3]}"
			file="$(eval "printf %s $file")" # Unescape

			if [[ -z "$value" ]]
			then
				unset "${varname}[\$file:\$kind]"
			else
				eval "${varname}[\$file:\$kind]=\"\$value\""
			fi

			file_property_kind_exists[$kind]=y
		fi
	done < "$filename"
}

# Compare file properties.
function AconfCompareFileProps() {
	LogEnter 'Comparing file properties...\n'

	typeset -ag system_only_file_props=()
	typeset -ag changed_file_props=()
	typeset -ag config_only_file_props=()

	local key
	for key in "${!system_file_props[@]}"
	do
		if [[ -z "${output_file_props[$key]+x}" ]]
		then
			system_only_file_props+=("$key")
		fi
	done

	for key in "${!system_file_props[@]}"
	do
		if [[ -n "${output_file_props[$key]+x}" && "${system_file_props[$key]}" != "${output_file_props[$key]}" ]]
		then
			changed_file_props+=("$key")
		fi
	done

	for key in "${!output_file_props[@]}"
	do
		if [[ -z "${system_file_props[$key]+x}" ]]
		then
			config_only_file_props+=("$key")
		fi
	done

	LogLeave
}

# Compare file information in $output_dir and $system_dir.
function AconfAnalyzeFiles() {

	#
	# Lost/modified files - diff
	#

	LogEnter 'Examining files...\n'

	LogEnter 'Loading data...\n'
	mkdir --parents "$tmp_dir"
	( cd "$output_dir"/files && find . -mindepth 1 -print0 ) | cut --zero-terminated -c 2- | sort --zero-terminated > "$tmp_dir"/output-files
	( cd "$system_dir"/files && find . -mindepth 1 -print0 ) | cut --zero-terminated -c 2- | sort --zero-terminated > "$tmp_dir"/system-files
	LogLeave

	Log 'Comparing file data...\n'

	typeset -ag system_only_files=()
	local file

	( comm -13 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			Log 'Only in system: %s\n' "$(Color C "%q" "$file")"
			system_only_files+=("$file")
		done

	typeset -ag changed_files=()

	( comm -12 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			local output_type system_type
			output_type=$(LC_ALL=C stat --format=%F "$output_dir"/files/"$file")
			system_type=$(LC_ALL=C stat --format=%F "$system_dir"/files/"$file")

			if [[ "$output_type" != "$system_type" ]]
			then
				Log 'Changed type (%s / %s): %s\n' \
					"$(Color Y "%q" "$output_type")" \
					"$(Color Y "%q" "$system_type")" \
					"$(Color C "%q" "$file")"
				changed_files+=("$file")
				continue
			fi

			if [[ "$output_type" == "directory" || "$system_type" == "directory" ]]
			then
				continue
			fi

			if ! diff --no-dereference --brief "$output_dir"/files/"$file" "$system_dir"/files/"$file" > /dev/null
			then
				Log 'Changed: %s\n' "$(Color C "%q" "$file")"
				changed_files+=("$file")
			fi
		done

	typeset -ag config_only_files=()

	( comm -23 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			Log 'Only in config: %s\n' "$(Color C "%q" "$file")"
			config_only_files+=("$file")
		done

	LogLeave 'Done (%s only in system, %s changed, %s only in config).\n'	\
			 "$(Color G "${#system_only_files[@]}")"						\
			 "$(Color G "${#changed_files[@]}")"							\
			 "$(Color G "${#config_only_files[@]}")"

	#
	# Modified file properties
	#

	LogEnter 'Examining file properties...\n'

	LogEnter 'Loading data...\n'
	unset orig_file_props # Also populated by AconfCompileSystem, so that it can be used by AconfDefaultFileProp
	typeset -Ag output_file_props ; AconfReadFileProps "$output_dir"/file-props.txt output_file_props
	typeset -Ag system_file_props ; AconfReadFileProps "$system_dir"/file-props.txt system_file_props
	typeset -Ag   orig_file_props ; AconfReadFileProps "$system_dir"/orig-file-props.txt orig_file_props
	LogLeave

	typeset -ag all_file_property_kinds
	all_file_property_kinds=("${!file_property_kind_exists[@]}")
	Print0Array all_file_property_kinds | sort --zero-terminated | mapfile -t -d $'\0' all_file_property_kinds

	AconfCompareFileProps

	LogLeave 'Done (%s only in system, %s changed, %s only in config).\n'	\
			 "$(Color G "${#system_only_file_props[@]}")"					\
			 "$(Color G "${#changed_file_props[@]}")"						\
			 "$(Color G "${#config_only_file_props[@]}")"
}

# The *_packages arrays are passed by name,
# so ShellCheck thinks the variables are unused:
# shellcheck disable=2034

# Prepare configuration and system state
function AconfCompile() {
	LogEnter 'Collecting data...\n'

	# Configuration

	AconfCompileOutput

	# System

	AconfCompileSystem

	# Vars

	< "$output_dir"/packages.txt         sort --unique | mapfile -t                   packages
	< "$system_dir"/packages.txt         sort --unique | mapfile -t         installed_packages

	< "$output_dir"/foreign-packages.txt sort --unique | mapfile -t           foreign_packages
	< "$system_dir"/foreign-packages.txt sort --unique | mapfile -t installed_foreign_packages

	AconfAnalyzeFiles

	LogLeave # Collecting data
}

####################################################################################################

pacman_opts=("$PACMAN")
aurman_opts=(aurman)
pacaur_opts=(pacaur)
yaourt_opts=(yaourt)
yay_opts=(yay)
makepkg_opts=(makepkg)
diff_opts=(diff '--color=auto')

aur_helper=
aur_helpers=(aurman pacaur yaourt yay makepkg)

# Only aconfmgr can use makepkg under root
if [[ $EUID == 0 ]]
then
	aur_helper=makepkg
fi

function DetectAurHelper() {
	if [[ -n "$aur_helper" ]]
	then
		return
	fi

	LogEnter 'Detecting AUR helper...\n'

	local helper
	for helper in "${aur_helpers[@]}"
	do
		if hash "$helper" 2> /dev/null
		then
			aur_helper=$helper
			LogLeave '%s... Yes\n' "$(Color C %s "$helper")"
			return
		fi
		Log '%s... No\n' "$(Color C %s "$helper")"
	done

	Log 'Can'\''t find even makepkg!?\n'
	Exit 1
}

base_devel_installed=n

function AconfMakePkg() {
	local install=true
	if [[ "$1" == --noinstall ]]
	then
		install=false
		shift
	fi

	local package="$1"
	local asdeps="${2:-false}"

	LogEnter 'Building foreign package %s from source.\n' "$(Color M %q "$package")"

	local pkg_dir="$tmp_dir"/aur/"$package"
	Log 'Using directory %s.\n' "$(Color C %q "$pkg_dir")"

	rm -rf "$pkg_dir"
	mkdir --parents "$pkg_dir"

	# Needed to clone the AUR repo. Should be replaced with curl/tar.
	AconfNeedProgram git git n

	if [[ $base_devel_installed == n ]]
	then
		LogEnter 'Making sure the %s group is installed...\n' "$(Color M base-devel)"
		ParanoidConfirm ''
		local base_devel_all base_devel_missing
		"$PACMAN" --sync --quiet --group base-devel | mapfile -t base_devel_all
		( "$PACMAN" --deptest "${base_devel_all[@]}" || true ) | mapfile -t base_devel_missing
		if [[ ${#base_devel_missing[@]} != 0 ]]
		then
			AconfInstallNative "${base_devel_missing[@]}"
		fi

		LogLeave
		base_devel_installed=y
	fi

	LogEnter 'Cloning...\n'
	git clone "https://aur.archlinux.org/$package.git" "$pkg_dir"
	LogLeave

	if [[ ! -f "$pkg_dir"/PKGBUILD ]]
	then
		Log 'No package description file found!\n'
		LogEnter 'Assuming this package is part of a package base:\n'

		LogEnter 'Retrieving package info...\n'
		AconfNeedProgram cower cower y
		local pkg_base
		pkg_base=$(cower --format %b --info "$package")
		LogLeave 'Done, package base is %s.\n' "$(Color M %q "$pkg_base")"

		AconfMakePkg "$pkg_base" "$asdeps" # recurse
		LogLeave # Package base
		LogLeave # Package
		return
	fi

	AconfMakePkgDir "$package" "$asdeps" "$install" "$pkg_dir"
}

function AconfMakePkgDir() {
	local package=$1
	local asdeps=$2
	local install=$3
	local pkg_dir=$4

	local gnupg_home
	gnupg_home="$(realpath -m "$tmp_dir/gnupg")"
	local makepkg_user=nobody # when running as root

	local infofile infofilename
	for infofilename in .SRCINFO .AURINFO
	do
		infofile="$pkg_dir"/"$infofilename"
		if test -f "$infofile"
		then
			LogEnter 'Checking dependencies...\n'

			local depends missing_depends dependency arch
			arch="$(uname -m)"
			# Filter out packages from the same base
			( grep -E $'^\t(make|check)?depends(_'"$arch"')? = ' "$infofile" || true ) \
				| sed 's/^.* = \([^<>=]*\)\([<>=].*\)\?$/\1/g' \
				| ( grep -vFf <(( grep '^pkgname = ' "$infofile" || true) \
									| sed 's/^.* = \(.*\)$/\1/g' ) \
						|| true ) \
				| mapfile -t depends

			if [[ ${#depends[@]} != 0 ]]
			then
				( "$PACMAN" --deptest "${depends[@]}" || true ) | mapfile -t missing_depends
				if [[ ${#missing_depends[@]} != 0 ]]
				then
					for dependency in "${missing_depends[@]}"
					do
						LogEnter '%s:\n' "$(Color M %q "$dependency")"
						if "$PACMAN" --query --info "$dependency" > /dev/null 2>&1
						then
							Log 'Already installed.\n' # Shouldn't happen, actually
						elif "$PACMAN" --sync --info "$dependency" > /dev/null 2>&1
						then
							Log 'Installing from repositories...\n'
							AconfInstallNative --asdeps "$dependency"
							Log 'Installed.\n'
						else
							local installed=false

							# Check if this package is provided by something in pacman repos.
							# `pacman -Si` will not give us that information,
							# however, `pacman -S` still works.
							AconfNeedProgram pacsift pacutils n
							local providers
							providers=$(pacsift --sync --exact --satisfies="$dependency" <&-)
							if [[ -n "$providers" ]]
							then
								Log 'Installing provider package from repositories...\n'
								AconfInstallNative --asdeps "$dependency"
								Log 'Installed.\n'
								installed=true
							fi

							if ! $installed
							then
								Log 'Installing from AUR...\n'
								AconfMakePkg "$dependency" true
								Log 'Installed.\n'
							fi
						fi

						LogLeave ''
					done
				fi
			fi

			LogLeave

			local keys
			( grep -E $'^\tvalidpgpkeys = ' "$infofile" || true ) | sed 's/^.* = \(.*\)$/\1/' | mapfile -t keys
			if [[ ${#keys[@]} != 0 ]]
			then
				LogEnter 'Checking PGP keys...\n'

				local key
				for key in "${keys[@]}"
				do
					local keyserver=pgp.mit.edu
					#local keyserver=subkeys.pgp.net

					export GNUPGHOME="$gnupg_home"

					if [[ ! -d "$GNUPGHOME" ]]
					then
						LogEnter 'Creating %s...\n' "$(Color C %s "$GNUPGHOME")"
						mkdir --parents "$GNUPGHOME"
						gpg --gen-key --batch <<EOF
Key-Type: DSA
Key-Length: 1024
Name-Real: aconfmgr
%no-protection
EOF
						LogLeave
					fi

					LogEnter 'Adding key %s...\n' "$(Color Y %q "$key")"
					#ParanoidConfirm ''

					LogEnter 'Receiving key...\n'
					gpg --keyserver "$keyserver" --recv-key "$key"
					LogLeave

					LogEnter 'Signing key...\n'
					gpg --quick-lsign-key "$key"
					LogLeave

					if [[ $EUID == 0 ]]
					then
						chmod 700 "$gnupg_home"
						chown -R $makepkg_user: "$gnupg_home"
					fi

					LogLeave
				done

				LogLeave
			fi
		fi
	done

	LogEnter 'Building...\n'
	(
		cd "$pkg_dir"
		mkdir --parents home
		local args=(env "HOME=$PWD/home" "GNUPGHOME=$gnupg_home" "${makepkg_opts[@]}")

		if [[ $EUID == 0 ]]
		then
			chown -R "$makepkg_user": .
			su -s /bin/bash "$makepkg_user" -c "GNUPGHOME=$(realpath ../../gnupg) $(printf ' %q' "${args[@]}")"

			if $install
			then
				if $asdeps
				then
					"${pacman_opts[@]}" --upgrade --asdeps ./*.pkg.tar.xz
				else
					"${pacman_opts[@]}" --upgrade ./*.pkg.tar.xz
				fi
			fi
		else
			if $asdeps
			then
				args+=(--asdeps)
			fi

			if $install
			then
				args+=(--install)
			fi

			"${args[@]}"
		fi
	)
	LogLeave

	LogLeave
}

function AconfInstallNative() {
	local asdeps=false asdeps_arr=()
	if [[ "$1" == --asdeps ]]
	then
		asdeps=true
		asdeps_arr=(--asdeps)
		shift
	fi

	local target_packages=("$@")
	if [[ $prompt_mode == never ]]
	then
		# Some prompts default to 'no'
		( yes || true ) | sudo "${pacman_opts[@]}" --confirm --sync "${asdeps_arr[@]}" "${target_packages[@]}"
	else
		sudo "${pacman_opts[@]}" --sync "${asdeps_arr[@]}" "${target_packages[@]}"
	fi
}

function AconfInstallForeign() {
	local asdeps=false asdeps_arr=()
	if [[ "$1" == --asdeps ]]
	then
		asdeps=true
		asdeps_arr=(--asdeps)
		shift
	fi

	local target_packages=("$@")

	DetectAurHelper

	case "$aur_helper" in
		aurman)
			"${aurman_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		pacaur)
			"${pacaur_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		yaourt)
			"${yaourt_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		yay)
			"${yay_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		makepkg)
			local package
			for package in "${target_packages[@]}"
			do
				AconfMakePkg "$package" "$asdeps"
			done
			;;
		*)
			Log 'Error: unknown AUR helper %q\n' "$aur_helper"
			false
			;;
	esac
}

function AconfNeedProgram() {
	local program="$1" # program that needs to be in PATH
	local package="$2" # package the program is available in
	local foreign="$3" # whether this is a foreign package

	if ! hash "$program" 2> /dev/null
	then
		if [[ $foreign == y ]]
		then
			LogEnter 'Installing foreign dependency %s:\n' "$(Color M %q "$package")"
			ParanoidConfirm ''
			AconfInstallForeign --asdeps "$package"
		else
			LogEnter 'Installing native dependency %s:\n' "$(Color M %q "$package")"
			ParanoidConfirm ''
			AconfInstallNative --asdeps "$package"
		fi
		LogLeave 'Installed.\n'
	fi
}

# Get the path to the package file (.pkg.tar.xz) for the specified package.
# Download or build the package if necessary.
function AconfNeedPackageFile() {
	set -e
	local package="$1"

	local info foreign
	if info="$("$PACMAN" --query --info "$package")"
	then
		if "$PACMAN" --query --quiet --foreign "$package" > /dev/null
		then
			foreign=true
		else
			foreign=false
		fi
	else
		if info="$("$PACMAN" --sync --info "$package")"
		then
			foreign=false
		else
			foreign=true
		fi
	fi

	local version='' architecture='' filename
	if [[ -n "$info" ]]
	then
		version="$(grep '^Version' <<< "$info" | sed 's/^.* : //g')"
		architecture="$(grep '^Architecture' <<< "$info" | sed 's/^.* : //g')"
		filename="$package-$version-$architecture.pkg.tar.xz"
	fi
	local filemask="$package-*-*.pkg.tar.xz"

	# try without downloading first
	local downloaded
	for downloaded in false true
	do
		local precise
		for precise in true false
		do
			# if we don't have the exact version, we can only do non-precise
			if $precise && [[ -z "$version" ]]
			then
				continue
			fi

			local dirs=()
			if $foreign
			then
				DetectAurHelper
				local -A tried_helper=()

				local helper
				for helper in "$aur_helper" "${aur_helpers[@]}"
				do
					if [[ ${tried_helper[$helper]+x} ]]
					then
						continue
					fi
					tried_helper[$helper]=y

					case "$helper" in
						aurman)
							dirs+=("${XDG_CACHE_HOME:-$HOME/.cache}/aurman/$package")
							;;
						pacaur)
							dirs+=("${XDG_CACHE_HOME:-$HOME/.cache}/pacaur/$package")
							;;
						yaourt)
							# yaourt does not save .pkg.xz files
							;;
						yay)
							dirs+=("${XDG_CACHE_HOME:-$HOME/.cache}/yay/$package")
							;;
						makepkg)
							dirs+=("$tmp_dir"/aur/"$package")
							;;
						*)
							Log 'Error: unknown AUR helper %q\n' "$aur_helper"
							false
							;;
					esac
				done
			else
				local dir
				( LC_ALL=C pacman --verbose 2>/dev/null || true ) \
					| sed -n 's/^Cache Dirs: \(.*\)$/\1/p' \
					| sed 's/  /\n/g' \
					| while read -r dir
				do
					if [[ -n "$dir" ]]
					then
						dirs+=("$dir")
					fi
				done
			fi

			local files=()
			local dir
			for dir in "${dirs[@]}"
			do
				if $precise
				then
					if sudo test -f "$dir"/"$filename"
					then
						files+=("$dir"/"$filename")
					fi
				else
					if sudo test -d "$dir"
					then
						sudo find "$dir" -type f -name "$filemask" -print0 | \
							while read -r -d $'\0' file
							do
								files+=("$file")
							done
					fi
				fi
			done

			local file
			for file in "${files[@]}"
			do
				local correct
				if $precise
				then
					correct=true
				else
					local pkgname
					pkgname=$(bsdtar -x --to-stdout --file "$file" .PKGINFO | \
								  sed -n 's/^pkgname = \(.*\)$/\1/p')
					if [[ "$pkgname" == "$package" ]]
					then
						correct=true
					else
						correct=false
					fi
				fi

				if $correct
				then
					printf '%s' "$file"
					return
				fi
			done
		done

		if $downloaded
		then
			Log 'Unable to find package file for package %s!\n' "$(Color M %q "$package")"
			Exit 1
		else
			if $foreign
			then
				LogEnter 'Building foreign package %s\n' "$(Color M %q "$package")" "$(Color C %q "$filename")"
				ParanoidConfirm ''

				local helper
				for helper in "$aur_helper" "${aur_helpers[@]}"
				do
					case "$helper" in
						aurman)
							"${aurman_opts[@]}" --makepkg --aur --makepkg "$package" 1>&2
							break
							;;
						pacaur)
							"${pacaur_opts[@]}" --makepkg --aur --makepkg "$package" 1>&2
							break
							;;
						yaourt)
							# yaourt does not save .pkg.xz files
							continue
							;;
						yay)
							# yay does not have a --makepkg option
							continue
							;;
						makepkg)
							AconfMakePkg --noinstall "$package"
							break
							;;
						*)
							Log 'Error: unknown AUR helper %q\n' "$aur_helper"
							false
							;;
					esac
				done

				LogLeave
			else
				LogEnter "Downloading package %s (%s) to pacman's cache\\n" "$(Color M %q "$package")" "$(Color C %q "$filename")"
				ParanoidConfirm ''
				sudo "$PACMAN" --sync --download --nodeps --nodeps --noconfirm "$package" 1>&2
				LogLeave
			fi
		fi
	done
}

# Extract the original file from a package to stdout
function AconfGetPackageOriginalFile() {
	local package="$1" # Package to extract the file from
	local file="$2" # Absolute path to file in package

	local package_file
	package_file="$(AconfNeedPackageFile "$package")"

	local args=(bsdtar -x --to-stdout --file "$package_file" "${file/\//}")
	if [[ -r "$package_file" ]]
	then
		"${args[@]}"
	else
		sudo "${args[@]}"
	fi
}

function AconfRestoreFile() {
	local package=$1
	local file=$2

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
}

# Move filesystem object at $1 to $2, replacing any existing one.
# Attempt to do so atomically, when possible.
# Do the right thing when filesystem objects differ, but never
# recursively remove directories (copy their attributes instead).
function AconfReplace() {
	local src=$1
	local dst=$2

	# Try direct mv first
	if ! sudo mv --no-target-directory "$src" "$dst" 2>/dev/null
	then
		# Direct mv failed - directory or object type mismatch
		if sudo rm --force --dir "$dst" 2>/dev/null
		then
			# Deleted target successfully, now overwrite it
			sudo mv --no-target-directory "$src" "$dst"
		else
			# rm failed - likely a non-empty directory; copy
			# attributes only
			sudo chmod --reference="$src" "$dst"
			sudo chown --reference="$src" "$dst"
			sudo touch --reference="$src" "$dst"
		fi
	fi
}

####################################################################################################

prompt_mode=normal # never / normal / paranoid

function Confirm() {
	local detail_func="$1"

	if [[ $prompt_mode == never ]]
	then
		return
	fi

	while true
	do
		if [[ -n "$detail_func" ]]
		then
			Log 'Proceed? [Y/n/d] '
		else
			Log 'Proceed? [Y/n] '
		fi
		read -r -n 1 answer < /dev/tty
		echo 1>&2
		case "$answer" in
			Y|y|'')
				return
				;;
			N|n)
				Log '%s\n' "$(Color R "User abort")"
				Exit 1
				;;
			D|d)
				$detail_func
				continue
				;;
			*)
				continue
				;;
		esac
	done
}

function ParanoidConfirm() {
	if [[ $prompt_mode == paranoid ]]
	then
		Confirm "$@"
	fi
}

####################################################################################################

log_indent=:

function Log() {
	if [[ "$#" != 0 && -n "$1" ]]
	then
		local fmt="$1"
		shift

		if [[ -z $ANSI_clear_line ]]
		then
			# Replace carriage returns in format string with newline
			# when colors are disabled. This avoids systemd's journal
			# from showing such lines as [# blob data].

			fmt=${fmt//\\r/\\n} # Replace the '\r' sequence
			                    # (backslash-r) , not actual carriage
			                    # returns.
		fi

		printf "${ANSI_clear_line}${ANSI_color_B}%s ${ANSI_color_W}${fmt}${ANSI_reset}" "$log_indent" "$@" 1>&2
	fi
}

function LogEnter() {
	Log "$@"
	log_indent=$log_indent:
}

function LogLeave() {
	if [[ $# == 0 ]]
	then
		Log 'Done.\n'
	else
		Log "$@"
	fi

	log_indent=${log_indent::-1}
}

function FatalError() {
	Log "$@"
	false
	# if we're here, errexit is not set
	Log 'Continuing after error. This is a bug, please report it.\n'
	Exit 1
}

function Color() {
	local var="ANSI_color_$1"
	printf -- "%s" "${!var}"
	shift
	# shellcheck disable=2059
	printf -- "$@"
	printf -- "%s" "${ANSI_color_W}"
}

# The ANSI_color_* variables are looked up by name:
# shellcheck disable=2034
function DisableColor() {
	ANSI_color_R=
	ANSI_color_G=
	ANSI_color_Y=
	ANSI_color_B=
	ANSI_color_M=
	ANSI_color_C=
	ANSI_color_W=
	ANSI_reset=
	ANSI_clear_line=
}

####################################################################################################

function OnError() {
	trap '' EXIT ERR

	LogEnter '%s! Stack trace:\n' "$(Color R "Fatal error")"

	local frame=0 str
	while str=$(caller $frame)
	do
		if [[ $str =~ ^([^\ ]*)\ ([^\ ]*)\ (.*)$ ]]
		then
			Log '%s:%s [%s]\n' "$(Color C "%q" "${BASH_REMATCH[3]}")" "$(Color G "%q" "${BASH_REMATCH[1]}")" "$(Color Y "%q" "${BASH_REMATCH[2]}")"
		else
			Log '%s\n' "$str"
		fi

		frame=$((frame+1))
	done

	LogLeave ''

	if [[ -d "$tmp_dir" ]]
	then
		local df dir
		df=$(($(stat -f --format="%a*%S" "$tmp_dir")))
		dir="$(realpath "$(dirname "$tmp_dir")")"
		if [[ $df -lt $warn_tmp_df_threshold ]]
		then
			LogEnter 'Probable cause: low disk space (%s bytes) in %s. Suggestions:\n' "$(Color G %s "$df")" "$(Color C %q "$dir")"
			Log '- Ignore more files and directories using %s directives;\n' "$(Color Y IgnorePath)"
			Log '- Free up more space in %s;\n' "$(Color C %q "$dir")"
			Log '- Set %s to another location before invoking %s.\n' "$(Color Y \$TMPDIR)" "$(Color Y aconfmgr)"
			LogLeave ''
		fi
	fi

	# Ensure complete abort when inside a string expansion
	exit 1
}
trap OnError EXIT ERR

function Exit() {
	trap '' EXIT ERR
	exit "${1:-0}"
}

####################################################################################################

# Print an array, one element per line (assuming IFS starts with \n).
# Work-around for Bash considering it an error to expand an empty array.
function PrintArray() {
	local name="$1" # Name of the global variable containing the array
	local size

	size="$(eval "echo \${#${name}""[*]}")"
	if [[ $size != 0 ]]
	then
		eval "echo \"\${${name}[*]}\""
	fi
}

# Ditto, but terminate elements with a NUL.
function Print0Array() {
	local name="$1" # Name of the global variable containing the array

	eval "$(cat <<EOF
	if [[ \${#${name}[*]} != 0 ]]
	then
		local item
		for item in "\${${name}[@]}"
		do
			printf '%s\\0' "\$item"
		done
	fi
EOF
)"
}

if [[ $EUID == 0 ]]
then
	function sudo() { "$@" ; }
fi

# cat a file; if it's not readable, cat via sudo.
function SuperCat() {
	local file="$1"

	if [[ -r "$1" ]]
	then
		cat "$1"
	else
		sudo cat "$1"
	fi
}

: # include in coverage
