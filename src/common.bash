# common.bash

# This file contains aconfmgr's common code, used by all commands.

####################################################################################################

# Globals

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

# Some limits for common-sense warnings.
# Feel free to override these in your configuration.
warn_size_threshold=$((10*1024*1024)) # Warn on copying files bigger than this
warn_file_count_threshold=1000        # Warn on finding this many lost files
warn_tmp_df_threshold=$((1024*1024))  # Warn on error if free space in $tmp_dir is below this

####################################################################################################

function AconfAddFile() {
	local file="$1" # Absolute path of file to add
	found_files+=("$file")
}

function LogLeaveDirStats() {
	local dir="$1"
	Log "Finalizing...\r"
	LogLeave "Done (%s native packages, %s foreign packages, %s files).\n"	\
			 "$(Color G "$(wc -l < "$dir"/packages.txt)")"					\
			 "$(Color G "$(wc -l < "$dir"/foreign-packages.txt)")"			\
			 "$(Color G "$(find "$dir"/files -not -type d | wc -l)")"
}

# Run user configuration scripts, to collect desired state into #output_dir
function AconfCompileOutput() {
	LogEnter "Compiling user configuration...\n"

	rm -rf "$output_dir"
	mkdir --parents "$output_dir"
	mkdir "$output_dir"/files
	touch "$output_dir"/packages.txt
	touch "$output_dir"/foreign-packages.txt
	touch "$output_dir"/file-props.txt
	mkdir --parents "$config_dir"

	# Configuration

	Log "Using configuration in %s\n" "$(Color C "%q" "$config_dir")"

	typeset -ag ignore_packages=()
	typeset -ag ignore_foreign_packages=()

	local found=n
	for file in "$config_dir"/*.sh
	do
		if [[ -e "$file" ]]
		then
			LogEnter "Sourcing %s...\n" "$(Color C "%q" "$file")"
			source "$file"
			found=y
			LogLeave ''
		fi
	done

	if [[ $found == y ]]
	then
		LogLeaveDirStats "$output_dir"
	else
		LogLeave "Done (configuration not found).\n"
	fi
}

skip_inspection=n

# Collect system state into $system_dir
function AconfCompileSystem() {
	LogEnter "Inspecting system state...\n"

	if [[ $skip_inspection == y ]]
	then
		LogLeave "Skipped.\n"
		return
	fi

	rm -rf "$system_dir"
	mkdir --parents "$system_dir"
	mkdir "$system_dir"/files
	touch "$system_dir"/file-props.txt

	### Packages

	LogEnter "Querying package list...\n"
	( pacman --query --quiet --explicit --native  || true ) | sort | ( grep -vFxf <(PrintArray ignore_packages        ) || true ) > "$system_dir"/packages.txt
	( pacman --query --quiet --explicit --foreign || true ) | sort | ( grep -vFxf <(PrintArray ignore_foreign_packages) || true ) > "$system_dir"/foreign-packages.txt
	LogLeave

	### Files

	typeset -ag found_files
	found_files=()

	# Lost files

	local ignore_args=()
	local ignore_path
	for ignore_path in "${ignore_paths[@]}"
	do
		ignore_args+=(-wholename "$ignore_path" -prune -o)
	done

	LogEnter "Enumerating managed files...\n"
	mkdir --parents "$tmp_dir"
	pacman --query --list --quiet | sed '/\/$/d' | sort --unique > "$tmp_dir"/managed-files
	LogLeave

	LogEnter "Searching for lost files...\n"

	local lost_file_count=0
	local line
	(												\
		sudo find / -not \(							\
			 "${ignore_args[@]}"					\
			 -type d								\
			 \) -print0								\
			| grep									\
				  --null --null-data				\
				  --invert-match					\
				  --fixed-strings					\
				  --line-regexp						\
				  --file "$tmp_dir"/managed-files	\
	) |												\
		while read -r -d $'\0' file
		do
			#echo "ignore_paths+='$file' # "
			if ((verbose))
			then
				Log "%s\r" "$(Color C "%q" "$file")"
			fi

			AconfAddFile "$file"
			lost_file_count=$((lost_file_count+1))

			if [[ $lost_file_count -eq $warn_file_count_threshold ]]
			then
				LogEnter "%s: reached %s lost files while in directory %s.\n" \
					"$(Color Y "Warning")" \
					"$(Color G "$lost_file_count")" \
					"$(Color C "%q" "$(dirname "$file")")"
				LogLeave "Perhaps add %s (or a parent directory) to configuration to ignore it.\n" \
					"$(Color Y "IgnorePath %q" "$(dirname "$file")"/'*')"
			fi
		done

	LogLeave "Done (%s lost files).\n" "$(Color G %s $lost_file_count)"

	# Modified files

	LogEnter "Searching for modified files...\n"

	AconfNeedProgram paccheck pacutils y
	local modified_file_count=0

	sudo sh -c "stdbuf -o0 paccheck --md5sum --files --backup --noupgrade 2>&1 || true" | \
		while read -r line
		do
			if [[ $line =~ ^(.*):\ \'(.*)\'\ md5sum\ mismatch ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"

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
					Log "%s: %s\n" "$(Color M "%q" "$package")" "$(Color C "%q" "$file")"
					AconfAddFile "$file"
					modified_file_count=$((modified_file_count+1))
				fi

			elif [[ $line =~ ^(.*):\  ]]
			then
				local package="${BASH_REMATCH[1]}"
				Log "%s...\r" "$(Color M "%q" "$package")"
				#echo "Now at ${BASH_REMATCH[1]}"
			fi
		done
	LogLeave "Done (%s modified files).\n" "$(Color G %s $modified_file_count)"

	LogEnter "Reading file attributes...\n"

	typeset -a found_file_types found_file_sizes found_file_modes found_file_owners found_file_groups
	if [[ ${#found_files[*]} == 0 ]]
	then
		Log "No files found, skipping.\n"
	else
		Log "Reading file types...\n"  ;  found_file_types=($(Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%F))
		Log "Reading file sizes...\n"  ;  found_file_sizes=($(Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%s))
		Log "Reading file modes...\n"  ;  found_file_modes=($(Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%a))
		Log "Reading file owners...\n" ; found_file_owners=($(Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%U))
		Log "Reading file groups...\n" ; found_file_groups=($(Print0Array found_files | sudo env LC_ALL=C xargs -0 stat --format=%G))
	fi

	LogLeave # Reading file attributes

	LogEnter "Processing found files...\n"

	local i
	for ((i=0; i<${#found_files[*]}; i++))
	do
		Log "%s/%s...\r" "$(Color G "$i")" "$(Color G "${#found_files[*]}")"

		local  file="${found_files[$i]}"
		local  type="${found_file_types[$i]}"
		local  size="${found_file_sizes[$i]}"
		local  mode="${found_file_modes[$i]}"
		local owner="${found_file_owners[$i]}"
		local group="${found_file_groups[$i]}"

		mkdir --parents "$(dirname "$system_dir"/files/"$file")"
		if [[ "$type" == "symbolic link" ]]
		then
			ln -s "$(sudo readlink "$file")" "$system_dir"/files/"$file"
		elif [[ "$type" == "regular file" || "$type" == "regular empty file" ]]
		then
			if [[ $size -gt $warn_size_threshold ]]
			then
				Log "%s: copying large file '%s' (%s bytes). Add %s to configuration to ignore.\n" "$(Color Y "Warning")" "$(Color C "%q" "$file")" "$(Color G "$size")" "$(Color Y "IgnorePath %q" "$file")"
			fi
			( sudo cat "$file" ) > "$system_dir"/files/"$file"
		else
			Log "%s: Skipping file '%s' with unknown type '%s'. Add to %s to ignore.\n" "$(Color Y "Warning")" "$(Color C "%q" "$file")" "$(Color G "$type")" "$(Color Y "ignore_paths")"
			continue
		fi

		{
			local defmode
			[[ "$type" == "symbolic link" ]] && defmode=777 || defmode=$default_file_mode

			[[  "$mode" == "$defmode" ]] || printf  "mode\t%s\t%q\n"  "$mode" "$file"
			[[ "$owner" == root       ]] || printf "owner\t%s\t%q\n" "$owner" "$file"
			[[ "$group" == root       ]] || printf "group\t%s\t%q\n" "$group" "$file"
		} >> "$system_dir"/file-props.txt
	done

	LogLeave # Processing found files

	LogLeaveDirStats "$system_dir" # Inspecting system state
}

####################################################################################################

typeset -A file_property_kind_exists

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
				unset "$varname[\$file:\$kind]"
			else
				eval "$varname[\$file:\$kind]=\"\$value\""
			fi

			file_property_kind_exists[$kind]=y
		fi
	done < "$filename"
}

# Compare file properties.
function AconfCompareFileProps() {
	LogEnter "Comparing file properties...\n"

	typeset -ag system_only_file_props=()
	typeset -ag changed_file_props=()
	typeset -ag config_only_file_props=()

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

# fixed by `shopt -s lastpipe`:
# shellcheck disable=2030,2031

# Compare file information in $output_dir and $system_dir.
function AconfAnalyzeFiles() {

	#
	# Lost/modified files - diff
	#

	LogEnter "Examining files...\n"

	LogEnter "Loading data...\n"
	mkdir --parents "$tmp_dir"
	( cd "$output_dir"/files && find . -not -type d -print0 ) | cut --zero-terminated -c 2- | sort --zero-terminated > "$tmp_dir"/output-files
	( cd "$system_dir"/files && find . -not -type d -print0 ) | cut --zero-terminated -c 2- | sort --zero-terminated > "$tmp_dir"/system-files
	LogLeave

	Log "Comparing file data...\n"

	typeset -ag system_only_files=()

	( comm -13 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			Log "Only in system: %s\n" "$(Color C "%q" "$file")"
			system_only_files+=("$file")
		done

	typeset -ag changed_files=()

	( comm -12 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			if ! diff --no-dereference --brief "$output_dir"/files/"$file" "$system_dir"/files/"$file" > /dev/null
			then
				Log "Changed: %s\n" "$(Color C "%q" "$file")"
				changed_files+=("$file")
			fi
		done

	typeset -ag config_only_files=()

	( comm -23 --zero-terminated "$tmp_dir"/output-files "$tmp_dir"/system-files ) | \
		while read -r -d $'\0' file
		do
			Log "Only in config: %s\n" "$(Color C "%q" "$file")"
			config_only_files+=("$file")
		done

	LogLeave "Done (%s only in system, %s changed, %s only in config).\n"	\
			 "$(Color G "${#system_only_files[@]}")"						\
			 "$(Color G "${#changed_files[@]}")"							\
			 "$(Color G "${#config_only_files[@]}")"

	#
	# Modified file properties
	#

	LogEnter "Examining file properties...\n"

	LogEnter "Loading data...\n"
	typeset -Ag output_file_props ; AconfReadFileProps "$output_dir"/file-props.txt output_file_props
	typeset -Ag system_file_props ; AconfReadFileProps "$system_dir"/file-props.txt system_file_props
	LogLeave

	typeset -ag all_file_property_kinds
	all_file_property_kinds=($(echo "${!file_property_kind_exists[*]}" | sort))

	AconfCompareFileProps

	LogLeave "Done (%s only in system, %s changed, %s only in config).\n"	\
			 "$(Color G "${#system_only_file_props[@]}")"					\
			 "$(Color G "${#changed_file_props[@]}")"						\
			 "$(Color G "${#config_only_file_props[@]}")"
}

# Prepare configuration and system state
function AconfCompile() {
	LogEnter "Collecting data...\n"

	# Configuration

	AconfCompileOutput

	# System

	AconfCompileSystem

	# Vars

	                  packages=($(< "$output_dir"/packages.txt sort --unique))
	        installed_packages=($(< "$system_dir"/packages.txt sort --unique))

	          foreign_packages=($(< "$output_dir"/foreign-packages.txt sort --unique))
	installed_foreign_packages=($(< "$system_dir"/foreign-packages.txt sort --unique))

	AconfAnalyzeFiles

	LogLeave # Collecting data
}

####################################################################################################

pacman_opts=(pacman)
pacaur_opts=(pacaur)
yaourt_opts=(yaourt)
makepkg_opts=(makepkg)
diff_opts=(diff --color=auto)

aur_helper=
aur_helpers=(pacaur yaourt makepkg)

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

	LogEnter "Detecting AUR helper...\n"

	local helper
	for helper in "${aur_helpers[@]}"
	do
		if which $helper > /dev/null 2>&1
		then
			aur_helper=$helper
			LogLeave "%s... Yes\n" "$(Color C %s "$helper")"
			return
		fi
		Log "%s... No\n" "$(Color C %s "$helper")"
	done

	Log "Can't find even makepkg!?\n"
	Exit 1
}

base_devel_installed=n

function AconfMakePkg() {
	local package="$1"

	LogEnter "Building foreign package %s from source.\n" "$(Color M %q "$package")"
	rm -rf "$tmp_dir"/aur/"$package"
	mkdir --parents "$tmp_dir"/aur/"$package"

	# Needed to clone the AUR repo. Should be replaced with curl/tar.
	AconfNeedProgram git git n

	if [[ $base_devel_installed == n ]]
	then
		LogEnter "Making sure the %s group is installed...\n" "$(Color M base-devel)"
		ParanoidConfirm ''
		local base_devel_all=($(pacman --sync --quiet --group base-devel))
		local base_devel_missing=($(pacman --deptest "${base_devel_all[@]}" || true))
		if [[ ${#base_devel_missing[@]} != 0 ]]
		then
			AconfInstallNative "${base_devel_missing[@]}"
		fi

		LogLeave
		base_devel_installed=y
	fi

	LogEnter "Cloning...\n"
	(
		cd "$tmp_dir"/aur
		git clone "https://aur.archlinux.org/$package.git"
	)
	LogLeave

	local gnupg_home="$(realpath -m "$tmp_dir/gnupg")"
	local makepkg_user=nobody # when running as root

	local infofile infofilename
	for infofilename in .SRCINFO .AURINFO
	do
		infofile="$tmp_dir"/aur/"$package"/"$infofilename"
		if test -f "$infofile"
		then
			LogEnter "Checking dependencies...\n"

			local depends missing_depends dependency arch
			arch="$(uname -m)"
			depends=($( ( grep -E $'^\t(make)?depends(_'"$arch"')? = ' "$infofile" || true ) | sed 's/^.* = \([^<>=]*\)\([<>=].*\)\?$/\1/g' ) )
			if [[ ${#depends[@]} != 0 ]]
			then
				missing_depends=($(pacman --deptest "${depends[@]}" || true))
				if [[ ${#missing_depends[@]} != 0 ]]
				then
					for dependency in "${missing_depends[@]}"
					do
						LogEnter "%s:\n" "$(Color M %q "$dependency")"
						if pacman --query --info "$dependency" > /dev/null 2>&1
						then
							Log "Already installed.\n" # Shouldn't happen, actually
						elif pacman --sync --info "$dependency" > /dev/null 2>&1
						then
							Log "Installing from repositories...\n"
							AconfInstallNative "$dependency"
							Log "Installed.\n"
						else
							Log "Installing from AUR...\n"
							AconfMakePkg "$dependency"
							Log "Installed.\n"
						fi

						# Mark as installed as dependency, unless it's
						# already in our list of packages to install.

						local iter_package explicit=n
						( Print0Array packages ; Print0Array foreign_packages ) | \
							while read -r -d $'\0' iter_package
							do
								if [[ "$iter_package" == "$dependency" ]]
								then
									explicit=y
									break
								fi
							done

						if [[ $explicit == n ]]
						then
							LogEnter "Marking as dependency...\n"
							sudo pacman --database --asdeps "$dependency"
							LogLeave
						fi

						LogLeave ''
					done
				fi
			fi

			LogLeave

			local keys
			keys=($( ( grep -E $'^\tvalidpgpkeys = ' "$infofile" || true ) | sed 's/^.* = \(.*\)$/\1/' ) )
			if [[ ${#keys[@]} != 0 ]]
			then
				LogEnter "Checking PGP keys...\n"

				local key
				for key in "${keys[@]}"
				do
					local keyserver=pgp.mit.edu
					#local keyserver=subkeys.pgp.net
					
					export GNUPGHOME="$gnupg_home"

					if [[ ! -d "$GNUPGHOME" ]]
					then
						LogEnter "Creating %s...\n" "$(Color C %s "$GNUPGHOME")"
						mkdir --parents "$GNUPGHOME"
						gpg --gen-key --batch <<EOF
Key-Type: DSA
Key-Length: 1024
Name-Real: aconfmgr
%no-protection
EOF
						LogLeave
					fi

					LogEnter "Adding key %s...\n" "$(Color Y %q "$key")"
					#ParanoidConfirm ''

					LogEnter "Receiving key...\n"
					gpg --keyserver "$keyserver" --recv-key "$key"
					LogLeave

					LogEnter "Signing key...\n"
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

	LogEnter "Building...\n"
	(
		cd "$tmp_dir"/aur/"$package"
		mkdir --parents home
		local command=(env "HOME=$PWD/home" "GNUPGHOME=$gnupg_home" "${makepkg_opts[@]}")
		if [[ $EUID == 0 ]]
		then
			chown -R nobody: .
			su -s /bin/bash nobody -c "GNUPGHOME=$(realpath ../../gnupg) $(printf ' %q' "${command[@]}")"
			"${pacman_opts[@]}" --upgrade ./*.pkg.tar.xz
		else
			"${command[@]}" --install
		fi
	)
	LogLeave

	LogLeave
}

function AconfInstallNative() {
	local target_packages=("$@")
	if [[ $prompt_mode == never ]]
	then
		# Some prompts default to 'no'
		( yes || true ) | sudo "${pacman_opts[@]}" --confirm --sync "${target_packages[@]}"
	else
		sudo "${pacman_opts[@]}" --sync "${target_packages[@]}"
	fi
}

function AconfInstallForeign() {
	local target_packages=("$@")

	DetectAurHelper

	case "$aur_helper" in
		pacaur)
			"${pacaur_opts[@]}" --sync --aur "${target_packages[@]}"
			;;
		yaourt)
			"${yaourt_opts[@]}" --sync --aur "${target_packages[@]}"
			;;
		makepkg)
			for package in "${target_packages[@]}"
			do
				AconfMakePkg "$package"
			done
			;;
		*)
			Log "Error: unknown AUR helper %q\n" "$aur_helper"
			false
			;;
	esac
}

function AconfNeedProgram() {
	local program="$1" # program that needs to be in PATH
	local package="$2" # package the program is available in
	local foreign="$3" # whether this is a foreign package

	if ! which "$program" > /dev/null 2>&1
	then
		if [[ $foreign == y ]]
		then
			LogEnter "Installing foreign dependency %s:\n" "$(Color M %q "$package")"
			ParanoidConfirm ''
			AconfInstallForeign "$package"
		else
			LogEnter "Installing native dependency %s:\n" "$(Color M %q "$package")"
			ParanoidConfirm ''
			AconfInstallNative "$package"
		fi
		LogLeave "Installed.\n"
	fi
}

# Get the path to the package file (.pkg.tar.xz) for the specified package.
function AconfNeedPackageFile() {
	local package="$1"

	local info
	info="$(pacman --sync --info "$package")"
	version="$(printf "%s" "$info" | grep '^Version' | sed 's/^.* : //g')"
	architecture="$(printf "%s" "$info" | grep '^Architecture' | sed 's/^.* : //g')"

	local file="/var/cache/pacman/pkg/$package-$version-$architecture.pkg.tar.xz"

	if [[ ! -f "$file" ]]
	then
		LogEnter "Downloading package %s (%s) to pacman's cache\n" "$(Color M %q "$package")" "$(Color C %q "$(basename "$file")")"
		ParanoidConfirm ''
		sudo pacman --sync --download --nodeps --nodeps --noconfirm "$package" 1>&2
		LogLeave
	fi

	if [[ ! -f "$file" ]]
	then
		Log "Error: Expected to find %s, but it is not present\n" "$(Color C %q "$file")"
		Exit 1
	fi

	printf "%s" "$file"
}

# Extract the original file from a package to stdout
function AconfGetPackageOriginalFile() {
	local package="$1" # Package to extract the file from
	local file="$2" # Absolute path to file in package

	local package_file
	package_file="$(AconfNeedPackageFile "$package")"

	bsdtar -x --to-stdout --file "$package_file" "${file/\//}"
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
			Log "Proceed? [Y/n/d] "
		else
			Log "Proceed? [Y/n] "
		fi
		read -r -n 1 answer < /dev/tty
		echo 1>&2
		case "$answer" in
			Y|y|'')
				return
				;;
			N|n)
				Log "%s\n" "$(Color R "User abort")"
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
		Log "Done.\n"
	else
		Log "$@"
	fi

	log_indent=${log_indent::-1}
}

function Color() {
	local var="ANSI_color_$1"
	printf "%s" "${!var}"
	shift
	printf "$@"
	printf "%s" "${ANSI_color_W}"
}

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

	LogEnter "%s! Stack trace:\n" "$(Color R "Fatal error")"

	local frame=0 str
	while str=$(caller $frame)
	do
		if [[ $str =~ ^([^\ ]*)\ ([^\ ]*)\ (.*)$ ]]
		then
			Log "%s:%s [%s]\n" "$(Color C "%q" "${BASH_REMATCH[3]}")" "$(Color G "%q" "${BASH_REMATCH[1]}")" "$(Color Y "%q" "${BASH_REMATCH[2]}")"
		else
			Log "%s\n" "$str"
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
			LogEnter "Probable cause: low disk space (%s bytes) in %s. Suggestions:\n" "$(Color G %s "$df")" "$(Color C %q "$dir")"
			Log "- Ignore more files and directories using %s directives;\n" "$(Color Y IgnorePath)"
			Log "- Free up more space in %s;\n" "$(Color C %q "$dir")"
			Log "- Set %s to another location before invoking %s.\n" "$(Color Y \$TMPDIR)" "$(Color Y aconfmgr)"
			LogLeave ''
		fi
	fi
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

	size="$(eval "echo \${#$name""[*]}")"
	if [[ $size != 0 ]]
	then
		eval "echo \"\${$name[*]}\""
	fi
}

# Ditto, but terminate elements with a NUL.
function Print0Array() {
	local name="$1" # Name of the global variable containing the array

	eval "$(cat <<EOF
	if [[ \${#$name[*]} != 0 ]]
	then
		local item
		for item in "\${${name}[@]}"
		do
			printf "%s\0" "\$item"
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
