# Test case configuration functions (integration tests)

###############################################################################
# Initialization

function TestInit() {
	# No TTY for confirmations
	pacman_opts+=(--noconfirm)
	makepkg_opts+=(--noconfirm)

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

AddPackage aur
IgnorePackage --foreign parent-package

IgnorePath /.dockerenv
IgnorePath /README
IgnorePath /aconfmgr/\*
IgnorePath /aconfmgr-packages/\*
IgnorePath /aconfmgr-repo/\*
IgnorePath /opt/aur

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
	local mtime=${8:-@0}

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
	"${prefix[@]}" touch --no-dereference --date "$mtime" "$fn"

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

	local timestamp=0
	if [[ -f "$dir"/time ]]
	then
		timestamp=$(stat --format=%Y "$dir"/time)
	fi

	if [[ "$EUID" -eq 0 ]]
	then
		chown -R nobody: /tmp/aconfmgr-build
		env -i -C /tmp/aconfmgr-build su nobody -s /bin/sh -c "env SOURCE_DATE_EPOCH=$timestamp makepkg"
	else
		env -i -C /tmp/aconfmgr-build SOURCE_DATE_EPOCH="$timestamp" makepkg
	fi
}

function TestCreatePackage() {
	local package=$1
	local kind=$2
	local pkgver=1.0
	local pkgrel=1
	local arch=x86_64
	local groups=()
	local time=@0

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
	touch --date "$time" "$dir"/time

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

	if [[ "$kind" == foreign ]] && $aur_initialized
	then
		(
			cd "$dir"/build

			{
				cat <<EOF
pkgbase = $package
	pkgdesc = Dummy aconfmgr test suite package
	pkgver = $pkgver
	pkgrel = $pkgrel
	arch = $arch
EOF
				if [[ -f files.tar ]]
				then
				cat <<EOF
	source = files.tar
	md5sums = SKIP
EOF
				fi
				cat <<EOF

pkgname = $package

EOF
			} > .SRCINFO

			git init .
			git add PKGBUILD .SRCINFO
			if [[ -f files.tar ]]
			then
				git add files.tar
			fi
			git commit -m 'Initial commit'
			git push aur@aur.archlinux.org:"$package".git master
		)
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

###############################################################################
# AUR

aur_initialized=false

function TestInitAUR() {
	LogEnter 'Initializing AUR support...\n'

	LogEnter 'Starting AUR...\n'
	sudo /opt/aur/start.sh
	LogLeave

	LogEnter 'Generating a SSH key...\n'
	mkdir -p ~/.ssh
	chmod 700 ~/.ssh
	ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
	LogLeave

	LogEnter 'Registering on AUR...\n'
	local args=(
		curl
		--fail
		--output /dev/null
		'http://127.0.0.1/register/'
		-H 'Host: aur.archlinux.org'
		-H 'Content-Type: application/x-www-form-urlencoded'
		--data-urlencode 'Action=NewAccount'
		--data-urlencode 'U=aconfmgr'
		--data-urlencode 'E=aconfmgr@thecybershadow.net'
		--data-urlencode 'R='
		--data-urlencode 'HP='
		--data-urlencode 'I='
		--data-urlencode 'K='
		--data-urlencode 'L=en'
		--data-urlencode 'TZ=UTC'
		--data-urlencode 'PK='"$(cat ~/.ssh/id_ed25519.pub)"
		--compressed
	) ; "${args[@]}"
	LogLeave

	LogEnter 'Adding SSH host keys...\n'
	ssh-keyscan aur.archlinux.org >> ~/.ssh/known_hosts
	LogLeave

	LogEnter 'Checking SSH...\n'
	ssh aur@aur.archlinux.org help
	LogLeave

	LogEnter 'Configuring git...\n'
	git config --global user.name aconfmgr
	git config --global user.email 'aconfmgr@thecybershadow.net'
	LogLeave

	aur_initialized=true

	LogLeave
}
