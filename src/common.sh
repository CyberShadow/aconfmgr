#!/bin/bash
# (for shellcheck)

IFS=$'\n'

config_dir=config
output_dir=output
system_dir=system # Current system configuration, to be compared against the output directory
tmp_dir=tmp

warn_size_threshold=$((10*1024*1024))
default_file_mode=644

ignore_paths=(
    '/dev'
    '/home'
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

ANSI_clear_line="[0K"
ANSI_color_R="[1;31m"
ANSI_color_G="[1;32m"
ANSI_color_Y="[1;33m"
ANSI_color_B="[1;34m"
ANSI_color_M="[1;35m"
ANSI_color_C="[1;36m"
ANSI_color_W="[1;39m"
ANSI_reset="[0m"

####################################################################################################

mkdir -p "$config_dir"

umask $((666 - default_file_mode))

function AconfAddFile() {
	local file="$1" # Absolute path of file to add
	found_files+=("$file")
}

# Run user configuration scripts, to collect desired state into #output_dir
function AconfCompileOutput() {
	LogEnter "Compiling user configuration...\n"

	rm -rf "$output_dir"
	mkdir "$output_dir"
	touch "$output_dir"/packages.txt
	touch "$output_dir"/foreign-packages.txt
	touch "$output_dir"/file-props.txt

	# Configuration

	typeset -ag ignore_packages=()
	typeset -ag ignore_foreign_packages=()

	for file in "$config_dir"/*.sh
	do
		if [[ -e "$file" ]]
		then
			Log "Sourcing %s...\n" "$(Color C "$file")"
			source "$file"
		fi
	done

	LogLeave
}

# Collect system state into $system_dir
function AconfCompileSystem() {
	LogEnter "Inspecting system state...\n"

	rm -rf "$system_dir"
	mkdir "$system_dir"
	touch "$system_dir"/file-props.txt

	### Packages

	LogEnter "Querying package list...\n"
	pacman --query --quiet --explicit --native  | sort | grep -vFxf <(PrintArray ignore_packages        ) > "$system_dir"/packages.txt
	pacman --query --quiet --explicit --foreign | sort | grep -vFxf <(PrintArray ignore_foreign_packages) > "$system_dir"/foreign-packages.txt
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

	LogEnter "Searching for lost files...\n"

	local first=y
	local line
	while read -r -d $'\0' line
	do
		#echo "ignore_paths+='$line' # "
		#Log "Found lost file: %s\n" "$(Color C "$line")"

		# The slow operation will be sorted and filtered,
		# so most of the time will be spent waiting for the first entry.
		if [[ $first == y ]]
		then
			Log "Registering...\n"
			first=n
		fi

		AconfAddFile "$line"
	done < <(																				\
		comm -13 --zero-terminated															\
			 <(pacman --query --list --quiet | sed '/\/$/d' | sort --unique | tr '\n' '\0')	\
			 <(sudo find / -not \(															\
					"${ignore_args[@]}"														\
					-type d																	\
					\) -print0 |															\
					  sort --unique --zero-terminated) )

	LogLeave # Searching for lost files

	# Modified files

	LogEnter "Searching for modified files...\n"
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
				Log "%s: %s\n" "$(Color M "$package")" "$(Color C "$file")"
				AconfAddFile "$file"
			fi

		elif [[ $line =~ ^(.*):\  ]]
		then
			local package="${BASH_REMATCH[1]}"
			Log "%s...\r" "$(Color M "$package")"
			#echo "Now at ${BASH_REMATCH[1]}"
		fi
	done < <(sudo sh -c "stdbuf -o0 paccheck --md5sum --files --backup --noupgrade 2>&1")
	LogLeave # Searching for modified files

	LogEnter "Reading file attributes...\n"

	typeset -a found_file_types found_file_sizes found_file_modes found_file_owners found_file_groups
	if [[ ${#found_files[*]} == 0 ]]
	then
		Log "No files found, skipping.\n"
	else
		Log "Reading file types...\n"  ;  found_file_types=($(Print0Array found_files | sudo xargs -0 stat --format=%F))
		Log "Reading file sizes...\n"  ;  found_file_sizes=($(Print0Array found_files | sudo xargs -0 stat --format=%s))
		Log "Reading file modes...\n"  ;  found_file_modes=($(Print0Array found_files | sudo xargs -0 stat --format=%a))
		Log "Reading file owners...\n" ; found_file_owners=($(Print0Array found_files | sudo xargs -0 stat --format=%U))
		Log "Reading file groups...\n" ; found_file_groups=($(Print0Array found_files | sudo xargs -0 stat --format=%G))
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
				Log "%s: copying large file '%s' (%s bytes). Add to %s to ignore.\n" "$(Color Y "Warning")" "$(Color C "$file")" "$(Color G "$size")" "$(Color Y "ignore_paths")"
			fi
			( sudo cat "$file" ) > "$system_dir"/files/"$file"
		else
			Log "%s: Skipping file '%s' with unknown type '%s'. Add to %s to ignore.\n" "$(Color Y "Warning")" "$(Color C "$file")" "$(Color G "$type")" "$(Color Y "ignore_paths")"
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

	LogLeave # Inspecting system state
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

	LogLeave # Collecting data
}

####################################################################################################

log_indent=:

function Log() {
	local fmt="$1"
	shift
	printf "${ANSI_clear_line}${ANSI_color_B}%s ${ANSI_color_W}${fmt}${ANSI_reset}" "$log_indent" "$@"
}

function LogEnter() {
	Log "$@"
	log_indent=$log_indent:
}

function LogLeave() {
	#[[ $# == 0 ]] || Log "Done.\n" && Log "$@"
	Log "Done.\n"
	log_indent=${log_indent::-1}
}

function Color() {
	local var="ANSI_color_$1"
	printf "%s" "${!var}"
	shift
	printf "$@"
	printf "%s" "${ANSI_color_W}"
}

####################################################################################################

function OnError() {
	echo
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
}
trap OnError EXIT

function ExitSuccess() {
	trap '' EXIT
	exit 0
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
