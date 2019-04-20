# Test case configuration functions (mock tests)

###############################################################################
# Initialization

function TestInit() {
	mkdir -p "$test_data_dir"/packages
	mkdir -p "$test_data_dir"/installed-packages

	test_fs_root="$test_data_dir"/files
}

function TestPhase_RunHook() {
	:
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

	local root
	if [[ -z "$package" ]]
	then
		root="$test_data_dir"
	else
		root="$test_data_dir"/package-files/"$package"
	fi

	case "$type" in
		file)
			TestWriteFile "$root"/files/"$path" "$contents"
			;;
		dir)
			test -z "$contents" || FatalError 'Attempting to create directory with non-empty contents\n'
			mkdir -p "$root"/files/"$path"
			;;
		link)
			local fn="$root"/files/"$path"
			mkdir -p "$(dirname "$fn")"
			ln -s "$contents" "$fn"
			;;
		*)
			FatalError 'Unknown filesystem object type %s\n' "$type"
			;;
	esac

	if [[ -n "$mode"  ]] ; then TestWriteFile "$root"/file-props/"$path".mode  "$mode"  ; fi
	if [[ -n "$owner" ]] ; then TestWriteFile "$root"/file-props/"$path".owner "$owner" ; fi
	if [[ -n "$group" ]] ; then TestWriteFile "$root"/file-props/"$path".group "$group" ; fi
	touch --no-dereference -d "$mtime" "$root"/files/"$path"
}

function TestDeleteFile() {
	local path=$1

	rm -rf "$test_data_dir"/files/"$path"
	rm -f "$test_data_dir"/file-props/"$path".{mode,owner,group}
}

###############################################################################
# Packages

function TestCreatePackage() {
	local package=$1
	local kind=$2
	local version=1.0
	local arch=x86_64
	local groups=()
	local time=@0

	shift 2
	local arg
	for arg in "$@"
	do
		eval "$arg"
	done

	local package_file="$test_data_dir"/files/var/cache/pacman/pkg/"$package"-"$version"-"$arch".pkg.tar.xz
	mkdir -p "$test_data_dir"/files/var/cache/pacman/pkg

	local package_dir="$test_data_dir"/packages/"$kind"/"$package"
	mkdir -p "$package_dir"

	if [[ -d "$test_data_dir"/package-files/"$package"/files ]]
	then
		mv "$test_data_dir"/package-files/"$package"/files "$package_dir"/
	else
		mkdir "$package_dir"/files
	fi
	if [[ -d "$test_data_dir"/package-files/"$package"/file-props ]]
	then
		mv "$test_data_dir"/package-files/"$package"/file-props "$package_dir"/
	fi

	printf 'pkgname = %s\n' "$package" > "$package_dir"/.PKGINFO
	tar --create -f "$package_file" -C "$package_dir" .PKGINFO

	find "$package_dir"/files -exec touch --no-dereference --date "$time" {} +

	local path
	find "$package_dir"/files -mindepth 1 -maxdepth 1 -printf '%P\0' | \
		while read -r -d $'\0' path
		do
			# local package_path="$package_dir"/files/"$path"
			local package_prop_path="$package_dir"/file-props/"$path"

			local opts=()
			if [[ -e "$package_prop_path".owner ]] ; then opts+=(--owner "$(cat "$package_prop_path".owner)") ; fi
			if [[ -e "$package_prop_path".group ]] ; then opts+=(--group "$(cat "$package_prop_path".group)") ; fi
			if [[ -e "$package_prop_path".mode  ]] ; then opts+=(--mode  "$(cat "$package_prop_path".mode )") ; fi

			tar --append -f "$package_file" "${opts[@]}" -C "$package_dir"/files "$path"
		done

	mkdir -p "$package_dir"/groups
	local group
	for group in "${groups[@]}"
	do
		touch "$package_dir"/groups/"$group"
	done
}

function TestInstallPackage() {
	local package=$1
	local kind=$2
	local inst_as=$3

	local package_dir="$test_data_dir"/packages/"$kind"/"$package"

	local path
	find "$package_dir"/files -mindepth 1 -maxdepth 1 -print0 | \
		while read -r -d $'\0' path
		do
			cp -a "$path" "$test_data_dir"/files/
		done

	cp -a "$package_dir" "$test_data_dir"/installed-packages/
	printf -- '%s' "$kind" > "$test_data_dir"/installed-packages/"$package"/kind
	printf -- '%s' "$inst_as" > "$test_data_dir"/installed-packages/"$package"/inst_as
}

function TestExpectPacManLog() {
	touch "$test_data_dir"/pacman.log
	diff -u /dev/stdin <( sed -E 's/^pacman (--noconfirm )?//g' "$test_data_dir"/pacman.log )
}
