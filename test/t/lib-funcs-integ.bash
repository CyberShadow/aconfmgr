# Test case configuration functions (integration tests)

###############################################################################
# Initialization

function TestInit() {
	# No TTY for confirmations
	pacman_opts+=(--noconfirm)

	# Configuration matching the Docker image
	cat > "$config_dir"/10-system.sh <<'EOF'
AddPackage arch-install-scripts
AddPackage autoconf
AddPackage automake
AddPackage binutils
AddPackage bison
AddPackage fakeroot
AddPackage file
AddPackage flex
AddPackage gawk
AddPackage gcc
AddPackage gettext
AddPackage grep
AddPackage groff
AddPackage gzip
AddPackage libtool
AddPackage m4
AddPackage make
AddPackage patch
AddPackage pkg-config
AddPackage sed
AddPackage sudo
AddPackage systemd
AddPackage texinfo
AddPackage which

AddPackage git
AddPackage pacutils

IgnorePath /.dockerenv
IgnorePath /README
IgnorePath /aconfmgr/\*
IgnorePath /aconfmgr-packages/\*

IgnorePath /etc/\*
IgnorePath /usr/\*
IgnorePath /srv/\*
IgnorePath /var/\*
EOF

	test_fs_root=/
}

###############################################################################
# Packages

function TestAddPackage() {
	local name=$1
	local kind=$2
	local inst_as=$3

	# printf '%s\t%s\t%s\n' "$name" "$kind" "$inst_as" >> "$test_data_dir"/packages.txt
	FatalError 'TODO\n'
}

function TestCreatePackageFile() {
	local package=$1
	local version=1.0 # $2
	local arch=x86_64 # $3

	FatalError 'TODO\n'
}

###############################################################################
# Files

function TestAddFSObj() {
	local package=$1 # empty string to add to filesystem
	local path=$2
	local type=$3 # file, dir, link
	local contents=$4 # file contents or link data
	local mode=${5:-}
	local owner=${6:-}
	local group=${7:-}

	if [[ -n "$package" ]]
	then
		FatalError 'TODO\n'
	else
		case "$type" in
			file)
				TestWriteFile "$path" "$contents"
				;;
			dir)
				test -z "$contents" || FatalError 'Attempting to create directory with non-empty contents\n'
				mkdir -p "$path"
				;;
			link)
				mkdir -p "$(dirname "$path")"
				ln -s "$contents" "$path"
				;;
			*)
				FatalError 'Unknown filesystem object type %s\n' "$type"
				;;
		esac

		if [[ -n "$mode"  ]] ; then chmod "$mode"  "$path" ; fi
		if [[ -n "$owner" ]] ; then chown "$owner" "$path" ; fi
		if [[ -n "$group" ]] ; then chgrp "$group" "$path" ; fi
	fi
}
