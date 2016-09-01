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

mkdir -p "$config_dir"

umask $((666 - default_file_mode))

function AconfAddFile() {
	mkdir --parents "$(dirname "$system_dir"/files/"$1")"
	local link=n
	if sudo test -h "$1"
	then
		ln -s "$(sudo readlink "$1")" "$system_dir"/files/"$1"
		link=y
	else
		local size
		size=$(sudo stat "$1" --format=%s)
		if [[ $size -gt $warn_size_threshold ]]
		then
			printf "Warning: copying large file (%s bytes). Add to ignore_paths to ignore.\n" "$size"
		fi
		( sudo cat "$1" ) > "$system_dir"/files/"$1"
	fi

	{
		local mode owner group defmode
		[[ $link == y ]] && defmode=777 || defmode=$default_file_mode
		 mode="$(sudo stat --format=%a "$1")"
		owner="$(sudo stat --format=%U "$1")"
		group="$(sudo stat --format=%G "$1")"

		[[ " $mode" == "$defmode" ]] || printf  "mode\t%s\t%q\n"  "$mode" "$1"
		[[ "$owner" == root       ]] || printf "owner\t%s\t%q\n" "$owner" "$1"
		[[ "$group" == root       ]] || printf "group\t%s\t%q\n" "$group" "$1"
	} >> "$system_dir"/file-props.txt
}

# Run user configuration scripts, to collect desired state into #output_dir
function AconfCompileOutput() {
	rm -rf "$output_dir"
	mkdir "$output_dir"
	touch "$output_dir"/packages.txt
	touch "$output_dir"/foreign-packages.txt
	touch "$output_dir"/file-props.txt

	# Configuration

	typeset -Ag ignore_packages
	typeset -Ag ignore_foreign_packages

	for file in "$config_dir"/*.sh
	do
		printf "Sourcing %s...\n" "$file"
		source "$file"
	done
}

# Collect system state into $system_dir
function AconfCompileSystem() {
	rm -rf "$system_dir"
	mkdir "$system_dir"

	### Packages

	echo "Querying package list..."
	pacman --query --quiet --explicit --native  | sort > "$system_dir"/packages.txt
	pacman --query --quiet --explicit --foreign | sort > "$system_dir"/foreign-packages.txt

	### Files

	# Untracked files

	local ignore_args=()
	local ignore_path
	for ignore_path in "${ignore_paths[@]}"
	do
		ignore_args+=(-wholename "$ignore_path" -prune -o)
	done

	echo "Searching for untracked files..."

	local line
	while read -r -d $'\0' line
	do
		#echo "ignore_paths+='$line' # "
		printf "Found untracked file: %s\n" "$line"
		AconfAddFile "$line"
	done < <(																				\
		comm -13 --zero-terminated															\
			 <(pacman --query --list --quiet | sed '/\/$/d' | sort --unique | tr '\n' '\0')	\
			 <(sudo find / -not \(															\
					"${ignore_args[@]}"														\
					-type d																	\
					\) -print0 |															\
					  sort --unique --zero-terminated) )

	# Modified files

	local ANSI_clear_line="[0K"

	echo "Searching for modified files..."
	while read -r line
	do
		if [[ $line =~ ^(.*):\ \'(.*)\'\ md5sum\ mismatch ]]
		then
			printf "%s: %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
			# TODO: Check ignores
			AconfAddFile "${BASH_REMATCH[2]}"
		elif [[ $line =~ ^(.*):\  ]]
		then
			printf "%s%s\r" "${ANSI_clear_line}" "${BASH_REMATCH[1]}"
			#echo "Now at ${BASH_REMATCH[1]}"
		fi
	done < <(sudo sh -c "stdbuf -o0 paccheck --md5sum --files --backup --noupgrade 2>&1")
	printf "\n"
}

# Prepare configuration and system state
function AconfCompile() {
	echo "Collecting data..."

	# Configuration

	echo "Compiling user configuration..."
	AconfCompileOutput

	# System

	echo "Inspecting system state..."
	AconfCompileSystem

	# Vars

	                  packages=($(< "$output_dir"/packages.txt sort --unique))
	        installed_packages=($(< "$system_dir"/packages.txt sort --unique))

	          foreign_packages=($(< "$output_dir"/foreign-packages.txt sort --unique))
	installed_foreign_packages=($(< "$system_dir"/foreign-packages.txt sort --unique))
}

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
