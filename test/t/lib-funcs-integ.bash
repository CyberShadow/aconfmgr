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
AddPackage git
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

IgnorePath /.dockerenv
IgnorePath /README
IgnorePath /aconfmgr/\*
IgnorePath /etc/\*
IgnorePath /usr/\*
IgnorePath /srv/\*
IgnorePath /var/\*
EOF
}

###############################################################################
# Packages

function TestAddPackage() {
	local name=$1
	local kind=$2
	local inst_as=$3

	# printf '%s\t%s\t%s\n' "$name" "$kind" "$inst_as" >> "$test_data_dir"/packages.txt
	FatalError TODO
}

function TestCreatePackageFile() {
	local package=$1
	local version=1.0 # $2
	local arch=x86_64 # $3

	FatalError TODO
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

	FatalError TODO
}
