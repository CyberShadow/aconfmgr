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
AddPackage gcc
AddPackage gettext
AddPackage grep
AddPackage groff
AddPackage gzip
AddPackage libtool
AddPackage m4
AddPackage make
AddPackage patch
AddPackage pkgconf
AddPackage sed
AddPackage sudo
AddPackage systemd
AddPackage texinfo
AddPackage which

AddPackage ruby-rdoc
AddPackage rubygems

AddPackage git
AddPackage pacutils

IgnorePackage --foreign parent-package

IgnorePath /.dockerenv
IgnorePath /README
IgnorePath /aconfmgr/\*
IgnorePath /aconfmgr-packages/\*
IgnorePath /aconfmgr-repo/\*

IgnorePath /etc/\*
IgnorePath /usr/\*
IgnorePath /srv/\*
IgnorePath /var/\*
EOF

	test_fs_root=/
}

function TestPhase_RunHook() {
	if [[ "${#test_adopted_packages[@]}" -gt 0 ]]
	then
		TestCreateParentPackage
	fi

	sudo rm -f /var/log/pacman.log
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

	local root prefix
	if [[ -z "$package" ]]
	then
		root=
		prefix=(sudo)
	else
		root="$test_data_dir"/packages/"$package"/files
		mkdir -p "$root"
		prefix=()
	fi
	local fn="$root"/"$path"

	case "$type" in
		file)
			"${prefix[@]}" mkdir -p "$(dirname "$fn")"
			printf -- "%s" "$contents" | "${prefix[@]}" sh -c "$(printf 'cat > %q' "$fn")"
			;;
		dir)
			test -z "$contents" || FatalError 'Attempting to create directory with non-empty contents\n'
			"${prefix[@]}" mkdir -p "$fn"
			;;
		link)
			"${prefix[@]}" mkdir -p "$(dirname "$fn")"
			"${prefix[@]}" ln -s "$contents" "$fn"
			;;
		*)
			FatalError 'Unknown filesystem object type %s\n' "$type"
			;;
	esac
	"${prefix[@]}" touch --no-dereference --date @0 "$fn"

	if [[ -n "$mode"  ]] ; then "${prefix[@]}" chmod "$mode"  "$fn" ; fi

	if [[ -z "$package" ]]
	then
		if [[ -n "$owner" ]] ; then "${prefix[@]}" chown --no-dereference "$owner" "$fn" ; fi
		if [[ -n "$group" ]] ; then "${prefix[@]}" chgrp --no-dereference "$group" "$fn" ; fi
	else
		tar rf "$test_data_dir"/packages/"$package"/files.tar \
			-C "$root" \
			--owner="${owner:-root}" \
			--group="${owner:-root}" \
			./"$path"
		rm -rf "$root"
	fi
}

function TestDeleteFile() {
	local path=$1

	sudo rm -rf "$path"
}

###############################################################################
# Packages

# Helper
function TestMakePkg() {
	local dir=$1

	rm -rf /tmp/aconfmgr-build
	cp -a "$dir" /tmp/aconfmgr-build

	if [[ "$EUID" -eq 0 ]]
	then
		chown -R nobody: /tmp/aconfmgr-build
		env -i -C /tmp/aconfmgr-build su nobody -s /bin/sh -c makepkg
	else
		env -i -C /tmp/aconfmgr-build makepkg
	fi
}

function TestCreatePackage() {
	local package=$1
	local kind=$2
	local pkgver=1.0
	local pkgrel=1
	local arch=x86_64
	local groups=()

	shift 2
	local arg
	for arg in "$@"
	do
		eval "$arg"
	done

	local groups_str
	groups_str=$(printf '%q ' "${groups[@]}")

	local dir="$test_data_dir"/packages/"$package"
	mkdir -p "$dir"
	printf '%s' "$kind" > "$dir"/kind

	mkdir "$dir"/build
	# shellcheck disable=SC2059
	(
		cat <<EOF
pkgname=$package
pkgver=$pkgver
pkgrel=$pkgrel
pkgdesc="Dummy aconfmgr test suite package"
arch=($arch)
groups=($groups_str)
EOF

		local tar="$dir"/files.tar
		if [[ -f "$tar" ]]
		then
			cp "$tar" "$dir"/build/
			cat <<'EOF'
source=(files.tar)
md5sums=(SKIP)

package() {
	tar xf "$srcdir"/files.tar -C "$pkgdir"
}
EOF
		fi
	) > "$dir"/build/PKGBUILD

	TestMakePkg "$dir"/build

	local pkg_fn="$package"-"$pkgver"-"$pkgrel"-"$arch".pkg.tar.xz
	local pkg_path=/tmp/aconfmgr-build/"$pkg_fn"
	test -e "$pkg_path" || FatalError 'Package expected to exist: %q\n' "$pkg_path"
	cp "$pkg_path" "$dir"/package.pkg.tar.xz

	if [[ "$kind" == native ]]
	then
		sudo repo-add /aconfmgr-repo/aconfmgr.db.tar "$pkg_path"
		sudo cp "$pkg_path" /aconfmgr-repo/
		sudo pacman -Sy
	fi
}

# Create dummy parent package to distinguish dependency from orphan packages.
function TestCreateParentPackage() {
	local dir="$test_data_dir"/parent-package
	mkdir "$dir"

	# shellcheck disable=SC2059
	printf "$(cat <<EOF
pkgname=parent-package
pkgver=1.0
pkgrel=1
pkgdesc="Dummy aconfmgr test suite parent package"
depends=(%s)
arch=(any)

EOF
)" "$(printf '%q ' "${test_adopted_packages[@]}")" > "$dir"/PKGBUILD

	TestMakePkg "$dir"

	sudo pacman -U --noconfirm /tmp/aconfmgr-build/parent-package-1.0-1-any.pkg.tar.xz
}

# Packages to give a parent to,
# so that they're not considered orphaned.
test_adopted_packages=()

function TestInstallPackage() {
	local package=$1
	local inst_as=$2

	local dir="$test_data_dir"/packages/"$package"

	local kind
	kind=$(cat "$dir"/kind)

	local args=(sudo pacman --noconfirm)
	case "$inst_as" in
		explicit)
			args+=(--asexplicit)
			;;
		dependency)
			args+=(--asdeps)
			test_adopted_packages+=("$package")
			;;
		orphan)
			args+=(--asdeps)
			;;
		*)
			FatalError "Unknown inst_as parameter: %s\n" "$inst_as"
	esac

	if [[ "$kind" == native ]]
	then
		"${args[@]}" -S "$package"
	else
		"${args[@]}" -U "$dir"/package.pkg.tar.xz
	fi

}

function TestExpectPacManLog() {
	sudo touch /var/log/pacman.log
	diff -u /dev/stdin <( sed -n 's/^.*\[PACMAN\] Running '\''pacman \(--noconfirm \)\?\(.*\)'\''$/\2/p' /var/log/pacman.log )
}
