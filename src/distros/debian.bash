# distros/debian.bash

# This file implements aconfmgr package management for apt-based distributions.

# APT=${APT:-apt}

# apt_opts=("$APT")
# aurman_opts=(aurman)
# pacaur_opts=(pacaur)
# yaourt_opts=(yaourt)
# yay_opts=(yay)
# makepkg_opts=(makepkg)

function apt_InstallPackages() {
	local asdeps=false
	if [[ "$1" == --asdeps ]]
	then
		asdeps=true
		shift
	fi

	local target_packages=("$@")
	sudo apt install "${target_packages[@]}"
	if $asdeps
	then
		debian_UnpinPackages "${target_packages[@]}"
	fi
}

function debian_RemovePackages() {
	local packages=("$@")

	sudo apt remove "${packages[@]}"
}

function apt_GetPackageDescription() {
	local package=$1

	dpkg-query -f '${Description}\n' -W "$package" | head -1
}

function apt_GetPackagesInGroup() {
	local group=$1

	# Debian tasks are the closest equivalent to groups.
	AconfNeedProgram tasksel tasksel n 1>&2
	tasksel --task-packages "$group"
}

function debian_GetPackagesFiles() {
	local packages=("$@")

	printf '%s\n' "${packages[@]}" | xargs dpkg -L | grep '^/' | sort -u
}

function debian_GetAllPackagesFiles() {
	apt_GetInstalledPackages | xargs dpkg -L | grep '^/' | sort -u
}

function apt_GetInstalledPackages() {
	LC_ALL=C dpkg --get-selections | grep -v '\bdeinstall$' | cut -d $'\t' -f 1 | cut -d : -f 1
}

function apt_GetExplicitlyInstalledPackages() {
	apt-mark showmanual
}

function debian_GetPackageOwningFile() {
	local file=$1

	local line
	dpkg-query -S "$file" | \
		while read -r line
		do
			if [[ "$line" =~ ^(.*?):\ (.*)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local path="${BASH_REMATCH[2]}"

				if [[ "$path" == "$file" ]]
				then
					printf -- '%s\n' "$package"
					return
				fi
			else
				Log '%s: Unknown line from dpkg -S: %q\n' "$(Color Y Warning)" "$line"
			fi
		done
}

function debian_GetOrphanPackages() {
	local line in_package_list
	LC_ALL=C apt-get -qs autoremove | \
		while read -r line
		do
			if [[ "$line" == 'The following packages will be REMOVED:' ]]
			then
				in_package_list=true
			elif $in_package_list
			then
				if [[ "$line" == '  '* ]]
				then
					local packages
					IFS=' ' read -ra packages <<< "$line"
					printf '%s\n' "${packages[@]}"
				else
					in_package_list=false
				fi
			fi
		done
}

function debian_UnpinPackages() {
	local packages=("$@")

	sudo apt-mark auto "${packages[@]}"
}

function debian_PinPackages() {
	local packages=("$@")

	sudo apt-mark manual "${packages[@]}"
}

# Get the path to the package file (.deb) for the specified package.
# Download or build the package if necessary.
function debian_NeedPackageFile() {
	set -e
	local package="$1"

	# TODO: use current version
	# TODO: use configured path
	# TODO: fix special characters in package name
	find /var/cache/apt/archives -name "$package"'_*.deb' | tail -1
}

# Extract the original file from a package to stdout
function debian_GetPackageOriginalFile() {
	local package="$1" # Package to extract the file from
	local file="$2" # Absolute path to file in package

	dpkg-deb --fsys-tarfile "$archive" | tar x --to-stdout --no-recursion ."$file" # ./usr/...
}

# Extract the original file from a package to a directory
function debian_ExtractPackageOriginalFile() {
	local archive="$1" # Path to the .pkg.tar.xz package to extract from
	local file="$2" # Path to the packaged file within the archive
	local target="$3" # Absolute path to the base directory to extract to

	dpkg-deb --fsys-tarfile "$archive" | sudo tar x --directory "$target" --no-recursion ."$file" # ./usr/...
}

# function BashBugFunc() {
# 	echo 1 | \
# 		while read -r package
# 		do
# 			true | true
# 		done
# }
# function CheckBashBug() {
# 	BashBugFunc > /dev/null
# }
# CheckBashBug

# Lists modified files.
# Format: <package><TAB><prop><TAB><expected-value><TAB><path><NUL>
# <prop> can be one of owner, group, mode, data, deleted, and progress.
function debian_FindModifiedFiles() {
	AconfNeedProgram debsums debsums n 1>&2

	Log '%s: Debian/apt support is work-in-progress. File attributes (type, mode, owner, group) are not tracked.\n' "$(Color Y "Warning")"

	local package
	while read -r package
	do
		printf '%s\t%s\t%s\t%s\0' "$package" progress '' ''

		local file
		sudo env LC_ALL=C sh -c "$(printf 'debsums -a -c %q || true' "$package")" | \
			while read -r file
			do
				printf '%s\t%s\t%s\t%q\0' "$package" data - "$file"
			done
	done < <(apt_GetInstalledPackages) # use process substitution to work around bash bug
}

function apt_Apply_InstallPackages() {
	local packages=("$@")

	function Details() { Log 'Installing the following packages:%s\n' "$(Color M " %q" "${packages[@]}")" ; }
	Confirm Details

	apt_InstallPackages "${packages[@]}"
}

: # include in coverage
