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

	rm -f /var/log/pacman.log
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

	local root
	if [[ -z "$package" ]]
	then
		root=
	else
		root="$test_data_dir"/packages/"$package"/files
	fi

	case "$type" in
		file)
			TestWriteFile "$root"/"$path" "$contents"
			;;
		dir)
			test -z "$contents" || FatalError 'Attempting to create directory with non-empty contents\n'
			mkdir -p "$root"/"$path"
			;;
		link)
			mkdir -p "$(dirname "$path")"
			ln -s "$contents" "$root"/"$path"
			;;
		*)
			FatalError 'Unknown filesystem object type %s\n' "$type"
			;;
	esac
	touch --no-dereference --date @0 "$root"/"$path"

	if [[ -n "$mode"  ]] ; then chmod "$mode"  "$path" ; fi
	if [[ -n "$owner" ]] ; then chown "$owner" "$path" ; fi
	if [[ -n "$group" ]] ; then chgrp "$group" "$path" ; fi
}

function TestDeleteFile() {
	local path=$1

	rm -rf "$path"
}

###############################################################################
# Packages

function TestCreatePackage() {
	local package=$1
	local kind=$2
	local pkgver=1.0 # $3
	local pkgrel=1
	local arch=x86_64 # $4

	local dir="$test_data_dir"/packages/"$package"
	mkdir -p "$dir"
	printf '%s' "$kind" > "$dir"/kind

	mkdir "$dir"/build
	# shellcheck disable=SC2059
	printf "$(cat <<EOF
pkgname=%q
pkgver=%q
pkgrel=%q
pkgdesc="Dummy aconfmgr test suite package"
arch=(%q)
source=(files.tar)
md5sums=(SKIP)

package() {
	tar xf "\$srcdir"/files.tar -C "\$pkgdir"
}

EOF
)" "$package" "$pkgver" "$pkgrel" "$arch" > "$dir"/build/PKGBUILD

	mkdir -p "$dir"/files
	tar cf "$dir"/build/files.tar -C "$dir"/files .

	rm -rf /tmp/aconfmgr-build
	cp -a "$dir"/build /tmp/aconfmgr-build
	chown -R nobody: /tmp/aconfmgr-build
	env -i -C /tmp/aconfmgr-build su nobody -s /bin/sh -c makepkg

	local pkg_fn="$package"-"$pkgver"-"$pkgrel"-"$arch".pkg.tar.xz
	local pkg_path=/tmp/aconfmgr-build/"$pkg_fn"
	test -e "$pkg_path" || FatalError 'Package expected to exist: %q\n' "$pkg_path"
	cp "$pkg_path" "$dir"/package.pkg.tar.xz

	if [[ "$kind" == native ]]
	then
		repo-add /aconfmgr-repo/aconfmgr.db.tar "$pkg_path"
		cp "$pkg_path" /aconfmgr-repo/
		pacman -Sy
	fi
}

# Create dummy parent package to distinguish dependency from orphan packages.
function TestCreateParentPackage() {
	local dir="$test_data_dir"/parent-package
	mkdir -p "$dir"

	mkdir "$dir"/build
	# shellcheck disable=SC2059
	printf "$(cat <<EOF
pkgname=parent-package
pkgver=1.0
pkgrel=1
pkgdesc="Dummy aconfmgr test suite parent package"
depends=(%s)
arch=(any)

EOF
)" "$(printf '%q ' "${test_adopted_packages[@]}")" > "$dir"/build/PKGBUILD

	mkdir -p "$dir"/files
	tar cf "$dir"/build/files.tar -C "$dir"/files .

	rm -rf /tmp/aconfmgr-build
	cp -a "$dir"/build /tmp/aconfmgr-build
	chown -R nobody: /tmp/aconfmgr-build
	env -i -C /tmp/aconfmgr-build su nobody -s /bin/sh -c makepkg
	pacman -U --noconfirm /tmp/aconfmgr-build/parent-package-1.0-1-any.pkg.tar.xz
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

	local args=(pacman --noconfirm)
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
	touch /var/log/pacman.log
	diff -u /dev/stdin <( sed -n 's/^.*\[PACMAN\] Running '\''pacman \(--noconfirm \)\?\(.*\)'\''$/\2/p' /var/log/pacman.log )
}
