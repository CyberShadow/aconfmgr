# Test case configuration functions (integration tests)

###############################################################################
# Initialization

function TestInit() {
	# No TTY for confirmations
	pacman_opts+=(--noconfirm)
	makepkg_opts+=(--noconfirm)

	pacaur_opts+=(--noconfirm --noedit)
	aurman_opts+=(--noconfirm --noedit --skip_news)
	yaourt_opts+=(--noconfirm)
	yay_opts+=(--noconfirm)
	paru_opts+=(--noconfirm)

	# pacaur insists that this is set, even if it will never inoke it
	export EDITOR=/bin/cat

	# Allows AUR helpers find perl tools etc.
	# shellcheck disable=SC2016
	PATH=$(env -i sh -c 'source /etc/profile 1>&2 ; printf -- %s "$PATH"')

	# Configuration matching the Docker image
	cat > "$config_dir"/10-system.sh <<'EOF'
AddPackage arch-install-scripts
AddPackage autoconf
AddPackage automake
AddPackage binutils
AddPackage bison
AddPackage fakeroot
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

	command sudo rm -f /var/log/pacman.log
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
		prefix=(command sudo)
	else
		root="$test_data_dir"/package-files/"$package"/files
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
		tar rf "$test_data_dir"/package-files/"$package"/files.tar \
			-C "$root" \
			--owner="${owner:-root}" \
			--group="${group:-root}" \
			./"$path"
		rm -rf "$root"
	fi
}

function TestDeleteFile() {
	local path=$1

	command sudo rm -rf "$path"
}

###############################################################################
# Packages

# Helper
function TestMakePkg() {
	local dir=$1
	shift

	local args=(makepkg --nodeps "$@")

	rm -rf /tmp/aconfmgr-build
	cp -a "$dir" /tmp/aconfmgr-build

	{
		cat /etc/makepkg.conf
		cat <<-'EOF'
			PKGEXT='.pkg.tar.zst'
			COMPRESSZST=(zstd -c -T0 -18 -)
		EOF
	} > /tmp/aconfmgr-build/makepkg.conf
	args+=(--config /tmp/aconfmgr-build/makepkg.conf)

	local timestamp=0
	if [[ -f "$dir"/time ]]
	then
		timestamp=$(stat --format=%Y "$dir"/time)
	fi

	if [[ "$EUID" -eq 0 ]]
	then
		chown -R nobody: /tmp/aconfmgr-build
		env -i -C /tmp/aconfmgr-build su nobody -s /bin/sh -c "env SOURCE_DATE_EPOCH=$timestamp $(printf ' %q' "${args[@]}")"
	else
		env -i -C /tmp/aconfmgr-build SOURCE_DATE_EPOCH="$timestamp" "${args[@]}"
	fi
}

function TestCreatePackage() {
	local package=$1
	local kind=$2
	local pkgver=1.0
	local pkgrel=1
	local arch=x86_64
	local groups=()
	local depends=()
	local provides=()
	local time=@0
	local pkgbuild
	local pkg_fn="$package"-"$pkgver"-"$pkgrel"-"$arch".pkg.tar.zst

	shift 2
	local arg
	for arg in "$@"
	do
		eval "$arg"
	done

	local dir="$test_data_dir"/packages/"$kind"/"$package"
	mkdir -p "$dir"
	touch --date "$time" "$dir"/time

	mkdir "$dir"/build

	local tar="$test_data_dir"/package-files/"$package"/files.tar
	if [[ -f "$tar" ]]
	then
		cp "$tar" "$dir"/build/
	fi

	# shellcheck disable=SC2059
	(
		if [[ -v pkgbuild ]]
		then
			printf -- %s "$pkgbuild"
		else
			cat <<EOF
pkgname=$package
pkgver=$pkgver
pkgrel=$pkgrel
pkgdesc="Dummy aconfmgr test suite package"
arch=($arch)
groups=($(PrintQArray groups))
depends=($(PrintQArray depends))
provides=($(PrintQArray provides))
EOF

			if [[ -f "$tar" ]]
			then
				cat <<'EOF'
source=(files.tar)
md5sums=(SKIP)

package() {
	tar xf "$srcdir"/files.tar -C "$pkgdir"
}
EOF
			fi
		fi
	) > "$dir"/build/PKGBUILD

	TestMakePkg "$dir"/build

	local pkg_path=/tmp/aconfmgr-build/"$pkg_fn"
	test -f "$pkg_path" || FatalError 'Package expected to exist: %q\n' "$pkg_path"
	cp "$pkg_path" "$dir"/
	ln -s "$pkg_fn" "$dir"/pkg

	if [[ "$kind" == native ]]
	then
		command sudo repo-add /aconfmgr-repo/aconfmgr.db.tar "$pkg_path"
		command sudo cp "$pkg_path" /aconfmgr-repo/
		command sudo pacman -Sy
	fi

	if [[ "$kind" == foreign && -f ~/aur-initialized ]]
	then
		(
			cd "$dir"/build

			TestMakePkg . --printsrcinfo > .SRCINFO

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

	rm -rf "$test_data_dir"/package-files/"$package"
}

# Delete an installable package.
function TestDeletePackage() {
	local package=$1
	local kind=$2

	local dir="$test_data_dir"/packages/"$kind"/"$package"
	test -d "$dir"
	rm -rf "$dir"

	if [[ "$kind" == native ]]
	then
		command sudo find /aconfmgr-repo/ -name "$package"'-*.pkg.tar.*' -delete
		command sudo repo-remove /aconfmgr-repo/aconfmgr.db.tar "$package"
		command sudo pacman -Sy
	fi

	if [[ "$kind" == foreign && -f ~/aur-initialized ]]
	then
		Log 'TOOO: delete packages from AUR\n'
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

	command sudo pacman -U --noconfirm /tmp/aconfmgr-build/parent-package-1.0-1-any.pkg.tar.*
}

# Packages to give a parent to,
# so that they're not considered orphaned.
test_adopted_packages=()

function TestInstallPackage() {
	local package=$1
	local kind=$2
	local inst_as=$3

	local dir="$test_data_dir"/packages/"$kind"/"$package"

	local args=(command sudo pacman --noconfirm)
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
		"${args[@]}" -U "$dir"/"$(readlink "$dir"/pkg)"
	fi

}

function TestExpectPacManLog() {
	command sudo touch /var/log/pacman.log
	diff -u /dev/stdin <( sed -n 's/^.*\[PACMAN\] Running '\''pacman \(--noconfirm \)\?\(.*\)'\''$/\2/p' /var/log/pacman.log )
}

###############################################################################
# AUR

function TestInitAUR() {
	test ! -f ~/aur-initialized || return 0

	LogEnter 'Initializing AUR support...\n'

	LogEnter 'Starting AUR...\n'
	command sudo /opt/aur/start.sh
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

	# Create "$tmp_dir" now with the correct mode.
	mkdir --mode=700 "$tmp_dir"

	touch ~/aur-initialized

	LogLeave
}

# Copies a package from the real AUR to our local instance.
function TestNeedAURPackage() {
	local package=$1
	local commit=$2
	shift 2
	local pkgbuild_extras=("$@")

	function TestEditHosts() {
		local transform=$1

		# Docker bind-mounts /etc/hosts; sed -i doesn't work
		local hosts
		hosts=$(cat /etc/hosts)
		printf -- %s "$hosts" | sed "$transform" | command sudo tee /etc/hosts > /dev/null
	}

	LogEnter 'Copying package %s from AUR...\n' "$(Color M "%q" "$package")"

	local dir="$test_aur_dir"/"$package"

	LogEnter 'Downloading package...\n'
	TestEditHosts 's/^.*aur.archlinux.org$/#\0/'
	mkdir -p "$(dirname "$dir")"
	git clone https://aur.archlinux.org/"$package".git "$dir"
	git -C "$dir" reset --hard "$commit"
	LogLeave

	if [[ "${#pkgbuild_extras[@]}" -gt 0 ]]
	then
		LogEnter 'Patching PKGBUILD...\n'
		test -f "$dir"/PKGBUILD
		printf '\n' >> "$dir"/PKGBUILD
		local line
		for line in "${pkgbuild_extras[@]}"
		do
			printf '%s\n' "$line" >> "$dir"/PKGBUILD
		done
		git -C "$dir" commit -am 'Patch PKGBUILD for aconfmgr test suite'
		LogLeave
	fi

	LogEnter 'Uploading package...\n'
	TestEditHosts 's/^#\(.*aur.archlinux.org\)$/\1/'
	git -C "$dir" push aur@aur.archlinux.org:"$package".git master
	LogLeave

	LogLeave
}

function TestNeedPacaur() {
	TestNeedAURPackage pacaur da18900a6fe888654867748fa976f8ae0ab96334
}

function TestNeedAuracle() {
	# shellcheck disable=SC2016,SC1004
	TestNeedAURPackage auracle-git a01e5f6921fd8e4142fe068310f87648c0b71c5f "$(cat <<-'EOF'
		source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")

		prepare() {
			cd "$_pkgname"
			local from='https://wrapdb.mesonbuild.com/v1/projects/\(.*\)/\(.*\)/\(.*\)/get_zip'
			local to='https://github.com/mesonbuild/\1/releases/download/\2-\3/\1.zip'
			sed -i "s#$from#$to#g" subprojects/*.wrap
		}
		EOF
)"
}

# Upload a new version of an AUR package with the given lines to
# override existing declarations.
function TestUpdateAurPackage() {
	local package=$1
	local kind=foreign
	shift
	local lines=("$@")

	(
		cd "$test_data_dir"/packages/"$kind"/"$package"/build
		local line
		printf '%s\n' "${lines[@]}" >> PKGBUILD
		TestMakePkg . --printsrcinfo > .SRCINFO
		git add PKGBUILD .SRCINFO
		git commit -m 'AUR package update'
		git push aur@aur.archlinux.org:"$package".git master
	)
}

# Common test code for testing integration with an AUR helper.
function TestAURHelper() {
	aur_helper=$1
	local cache_dir=$2
	local can_build_only=$3

	TestPhase_Setup ###############################################################
	TestAddPackageFile test-package /testfile.txt 'File contents'
	TestCreatePackage test-package foreign

	TestPhase_Run #################################################################

	LogEnter 'Test installing a package:\n'
	TestAddConfig AddPackage --foreign test-package
	AconfApply
	diff -u <(cat /testfile.txt) <(printf 'File contents')
	test -z "$cache_dir" -o -d "$cache_dir"
	LogLeave 'OK\n'

	LogEnter 'Test getting a file from an installed package:\n'
	diff -u "$(GetPackageOriginalFile test-package /testfile.txt)" <(printf 'File contents')
	RemoveFile /testfile.txt
	LogLeave 'OK\n'

	LogEnter 'Test getting a file from a non-installed package:\n'
	command sudo pacman -R --noconfirm test-package
	diff -u "$(GetPackageOriginalFile test-package /testfile.txt)" <(printf 'File contents')
	RemoveFile /testfile.txt
	LogLeave 'OK\n'

	if "$can_build_only"
	then
		LogEnter 'Test getting a file from a non-installed package (clean cache):\n'
		test -z "$cache_dir" || rm -rf "$cache_dir"
		diff -u "$(GetPackageOriginalFile test-package /testfile.txt)" <(printf 'File contents')
		test -z "$cache_dir" -o -d "$cache_dir"
		RemoveFile /testfile.txt
		LogLeave 'OK\n'

		LogEnter 'Test getting a file from another version of the package:\n'
		test -z "$cache_dir" || rm -rf "$cache_dir"
		TestUpdateAurPackage test-package 'pkgver=2.0'
		diff -u "$(GetPackageOriginalFile test-package /testfile.txt)" <(printf 'File contents')
		test -z "$cache_dir" -o -d "$cache_dir"
		RemoveFile /testfile.txt
		LogLeave 'OK\n'
	fi
}
