# distros/arch.bash

# This file implements aconfmgr package management for pacman-based distributions.

PACMAN=${PACMAN:-pacman}

pacman_opts=("$PACMAN")
aurman_opts=(aurman)
pacaur_opts=(pacaur)
yaourt_opts=(yaourt)
yay_opts=(yay)
makepkg_opts=(makepkg)

aur_helper=
aur_helpers=(aurman pacaur yaourt yay makepkg)

distro=arch
package_sources=(pacman aur)

# Only aconfmgr can use makepkg under root
if [[ $EUID == 0 ]]
then
	aur_helper=makepkg
fi

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
			pacman_InstallPackages "${base_devel_missing[@]}"
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

		if [[ "$package" == cower ]]
		then
			FatalError 'Failed to download aconfmgr dependency!\n'
		fi

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
							pacman_InstallPackages --asdeps "$dependency"
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
								pacman_InstallPackages --asdeps "$dependency"
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

					local ok=false
					local keyserver
					for keyserver in keys.gnupg.net pgp.mit.edu # subkeys.pgp.net
					do
						LogEnter 'Trying keyserver %s...\n' "$(Color C %s "$keyserver")"
						if gpg --keyserver "$keyserver" --recv-key "$key"
						then
							ok=true
							LogLeave 'OK!\n'
							break
						else
							LogLeave 'Error...\n'
						fi
					done

					if ! $ok
					then
						FatalError 'No keyservers succeeded.\n'
					fi

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

	LogEnter 'Evaluating environment...\n'
	local path
	# shellcheck disable=SC2016
	path=$(env -i sh -c 'source /etc/profile 1>&2 ; printf -- %s "$PATH"')
	LogLeave

	LogEnter 'Building...\n'
	(
		cd "$pkg_dir"
		mkdir --parents home
		local args=(env -i "PATH=$path" "HOME=$PWD/home" "GNUPGHOME=$gnupg_home" "${makepkg_opts[@]}")

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

function pacman_InstallPackages() {
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

function aur_InstallPackages() {
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
			RunExternal "${aurman_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		pacaur)
			RunExternal "${pacaur_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		yaourt)
			RunExternal "${yaourt_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
			;;
		yay)
			RunExternal "${yay_opts[@]}" --sync --aur "${asdeps_arr[@]}" "${target_packages[@]}"
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

function arch_RemovePackages() {
	local packages=("$@")

	sudo "${pacman_opts[@]}" --remove "${packages[@]}"
}

function pacman_GetPackageDescription() {
	local package=$1

	LC_ALL=C "$PACMAN" --query --info "$package" | grep '^Description' | cut -d ':' -f 2
}
function aur_GetPackageDescription() { pacman_GetPackageDescription "$@" ; }

function pacman_GetPackagesInGroup() {
	local group=$1

	"$PACMAN" --sync --quiet --groups "$group"
}

function aur_GetPackagesInGroup() {
	# Bulk operations on packages from AUR by group is probably a bad idea
	FatalError 'AUR group query is not implemented\n'
}

function arch_GetPackagesFiles() {
	local packages=("$@")

	"$PACMAN" --query --list --quiet "${packages[@]}" | sed 's#\/$##'
}

function arch_GetAllPackagesFiles() {
	( "$PACMAN" --query --list --quiet || true ) | sed 's#\/$##'
}

function pacman_GetInstalledPackages          () { "$PACMAN" --query --quiet            --native  || true ; }
function aur_GetInstalledPackages             () { "$PACMAN" --query --quiet            --foreign || true ; }
function pacman_GetExplicitlyInstalledPackages() { "$PACMAN" --query --quiet --explicit --native  || true ; }
function aur_GetExplicitlyInstalledPackages   () { "$PACMAN" --query --quiet --explicit --foreign || true ; }

function arch_GetPackageOwningFile() {
	local file=$1

	("$PACMAN" --query --owns --quiet "$file" || true) | head -n 1
}

function arch_GetOrphanPackages() {
	"$PACMAN" --query --unrequired --unrequired --deps --quiet || true
}

function arch_UnpinPackages() {
	local packages=("$@")

	sudo "$PACMAN" --database --asdeps "${packages[@]}"
}

function arch_PinPackages() {
	local packages=("$@")

	sudo "$PACMAN" --database --asexplicit "${packages[@]}"
}

# Get the path to the package file (.pkg.tar.xz) for the specified package.
# Download or build the package if necessary.
function arch_NeedPackageFile() {
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
				LogEnter 'Building foreign package %s\n' "$(Color M %q "$package")"
				ParanoidConfirm ''

				local helper
				for helper in "$aur_helper" "${aur_helpers[@]}"
				do
					case "$helper" in
						aurman)
							# aurman does not have a --makepkg option
							;;
						pacaur)
							if command -v "${pacaur_opts[0]}" > /dev/null
							then
								RunExternal "${pacaur_opts[@]}" --makepkg --aur --makepkg "$package" 1>&2
								break
							fi
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
function arch_GetPackageOriginalFile() {
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

# Extract the original file from a package to a directory
function arch_ExtractPackageOriginalFile() {
	local archive="$1" # Path to the .pkg.tar.xz package to extract from
	local file="$2" # Path to the packaged file within the archive
	local target="$3" # Absolute path to the base directory to extract to

	sudo tar x --directory "$target" --file "$archive" --no-recursion "${file/\//}"
}

# Lists modified files.
# Format: <package><TAB><prop><TAB><expected-value><TAB><path><NUL>
# <prop> can be one of owner, group, mode, data, deleted, and progress.
function arch_FindModifiedFiles() {
	AconfNeedProgram paccheck pacutils n 1>&2

	sudo sh -c "LC_ALL=C stdbuf -o0 paccheck --md5sum --files --file-properties --backup --noupgrade 2>&1 || true" | \
		while read -r line
		do
			if [[ $line =~ ^(.*):\ \'(.*)\'\ (type|size|modification\ time|md5sum|UID|GID|permission|symlink\ target)\ mismatch\ \(expected\ (.*)\)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				local kind="${BASH_REMATCH[3]}"
				local value="${BASH_REMATCH[4]}"

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
						prop=data
						value=-
						;;
					*)
						prop=
						;;
				esac

				if [[ -n "$prop" ]]
				then
					printf '%s\t%s\t%s\t%q\0' "$package" "$prop" "$value" "$file"
				fi
			elif [[ $line =~ ^(.*):\ \'(.*)\'\ missing\ file$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				printf '%s\t%s\t%s\t%s\0' "$package" deleted n "$file"
			elif [[ $line =~ ^warning:\ (.*):\ \'(.*)\'\ read\ error\ \(No\ such\ file\ or\ directory\)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				local file="${BASH_REMATCH[2]}"
				# Ignore
			elif [[ $line =~ ^(.*):\ all\ files\ match\ (database|mtree|mtree\ md5sums)$ ]]
			then
				local package="${BASH_REMATCH[1]}"
				printf '%s\t%s\t%s\t%s\0' "$package" progress '' ''
			else
				Log 'Unknown paccheck output line: %s\n' "$(Color Y "%q" "$line")"
			fi
		done
}

function pacman_Apply_InstallPackages() {
	local packages=("$@")

	function Details() { Log 'Installing the following native packages:%s\n' "$(Color M " %q" "${packages[@]}")" ; }
	ParanoidConfirm Details

	pacman_InstallPackages "${packages[@]}"
}

function aur_Apply_InstallPackages() {
	local packages=("$@")

	function Details() { Log 'Installing the following foreign packages:%s\n' "$(Color M " %q" "${packages[@]}")" ; }
	Confirm Details

	# If an AUR helper is present in the list of packages to be installed,
	# install it first, then use it to install the rest of the foreign packages.
	function InstallAurHelper() {
		local package helper
		for package in "${uninstalled_source_packages[@]}"
		do
			for helper in "${aur_helpers[@]}"
			do
				if [[ "$package" == "$helper" ]]
				then
					LogEnter 'Installing AUR helper %s...\n' "$(Color M %q "$helper")"
					ParanoidConfirm ''
					aur_InstallPackages "$package"
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

	aur_InstallPackages "${uninstalled_source_packages[@]}"
}

: # include in coverage
