# helpers.bash

# This file contains helper functions for the generated configuration scripts.

#
# AddPackage [--foreign] PACKAGE...
#
# Adds a package to the list of packages to be installed.
#

function AddPackage() {
	local fn=packages.txt
	if [[ "$1" == "--foreign" ]]
	then
		shift
		fn=foreign-packages.txt
	fi

	printf "%q\n" "$@" >> "$output_dir"/"$fn"
}

#
# RemovePackage [--foreign] PACKAGE...
#
# Removes an earlier-added package to the list of packages to be installed.
#
# Emitted by `aconfmgr save` when a package is present in the configuration,
# but absent on the system.
#
# You should refactor out any occurrences of this function from your configuration.
#

function RemovePackage() {
	local fn=packages.txt
	if [[ "$1" == "--foreign" ]]
	then
		shift
		fn=foreign-packages.txt
	fi

	local package
	for package in "$@"
	do
		sed -i "$output_dir"/"$fn" -e "/^${package}\$/d"
	done
}

#
# IgnorePackage [--foreign] PACKAGE...
#
# Adds a package to the list of packages to be ignored.
#

function IgnorePackage() {
	if [[ "$1" == "--foreign" ]]
	then
		shift
		ignore_foreign_packages+=("$@")
	else
		ignore_packages+=("$@")
	fi
}

#
# CopyFile PATH [MODE [OWNER [GROUP]]]
#
# Copies a file from the "files" subdirectory to the output.
#
# The specified path should be relative to the root of the "files" subdirectory.
#
# If MODE, OWNER and GROUP are unspecified, they default to
# "644", "root" and "root" respectively for new files.
#

function CopyFile() {
	local file="$1"
	local mode="${2:-}"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$(dirname "$output_dir"/files/"$file")"

	cp --no-dereference \
	   "$config_dir"/files/"$file" \
	   "$output_dir"/files/"$file"

	SetFileProperty "$file" mode  "$mode"
	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"
}

#
# CreateFile PATH [MODE [OWNER [GROUP]]]
#
# Creates an empty file, to be included in the output.
# Prints its absolute path to standard output.
#

function CreateFile() {
	local file="$1"
	local mode="${2:-}"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$(dirname "$output_dir"/files/"$file")"

	truncate --size 0 "$output_dir"/files/"$file"

	SetFileProperty "$file" mode  "$mode"
	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"

	printf "%s" "$output_dir"/files/"$file"
}

#
# GetPackageOriginalFile PACKAGE PATH
#
# Extracts the original file from a package's archive for inclusion in the output.
# Prints its absolute path to standard output.
#
# As in the case of CreateFile, the file can be further modified after extraction.
#

function GetPackageOriginalFile() {
	local package="$1" # Package to extract the file from
	local file="$2" # Absolute path to file in package

	local output_file="$output_dir"/files/"$file"

	mkdir --parents "$(dirname "$output_file")"

	AconfGetPackageOriginalFile	"$package" "$file" > "$output_file"

	printf "%s" "$output_file"
}

#
# CreateLink PATH TARGET [OWNER [GROUP]]
#
# Creates a symbolic link with the specified target.
#

function CreateLink() {
	local file="$1"
	local target="$2"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$(dirname "$output_dir"/files/"$file")"

	ln --symbolic "$target" "$output_dir"/files/"$file"

	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"
}

#
# RemoveFile PATH
#
# Removes an earlier-added file.
#
# Emitted by `aconfmgr save` when a file is present in the configuration,
# but absent on the system.
#
# You should refactor out any occurrences of this function from your configuration.
#

function RemoveFile() {
	local file="$1"

	rm "$output_dir"/files/"$file"
}

#
# SetFileProperty PATH TYPE VALUE
#
# Sets a file property.
# TYPE can be "owner", "group" or "mode".
#

function SetFileProperty() {
	local file="$1"
	local type="$2"
	local value="$3"

	printf "%s\t%s\t%q\n" "$type" "$value" "$file" >> "$output_dir"/file-props.txt
}

#
# IgnorePath PATH
#
# Adds the specified path to the list of ignored paths.
#
# The argument should be a shell pattern, e.g. '/etc/foo/*'.
#

function IgnorePath() {
	ignore_paths+=("$@")
}
