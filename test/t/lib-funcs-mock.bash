# Test case configuration functions (mock tests)

###############################################################################
# Initialization

function TestInit() {
	touch "$test_data_dir"/packages.txt
	mkdir -p "$test_data_dir"/packages

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
		root="$test_data_dir"/packages/"$package"
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

	mkdir -p "$test_data_dir"/packages/"$package"/files
	printf '%s' "$kind" > "$test_data_dir"/packages/"$package"/kind

	printf 'pkgname = %s\n' "$package" > "$test_data_dir"/packages/"$package"/.PKGINFO
	tar --create -f "$package_file" -C "$test_data_dir"/packages/"$package" .PKGINFO

	find "$test_data_dir"/packages/"$package"/files -exec touch --no-dereference --date "$time" {} +

	local path
	find "$test_data_dir"/packages/"$package"/files -mindepth 1 -maxdepth 1 -printf '%P\0' | \
		while read -r -d $'\0' path
		do
			# local package_path="$test_data_dir"/packages/"$package"/files/"$path"
			local package_prop_path="$test_data_dir"/packages/"$package"/file-props/"$path"

			local opts=()
			if [[ -e "$package_prop_path".owner ]] ; then opts+=(--owner "$(cat "$package_prop_path".owner)") ; fi
			if [[ -e "$package_prop_path".group ]] ; then opts+=(--group "$(cat "$package_prop_path".group)") ; fi
			if [[ -e "$package_prop_path".mode  ]] ; then opts+=(--mode  "$(cat "$package_prop_path".mode )") ; fi

			tar --append -f "$package_file" "${opts[@]}" -C "$test_data_dir"/packages/"$package"/files "$path"
		done

	mkdir -p "$test_data_dir"/packages/"$package"/groups
	local group
	for group in "${groups[@]}"
	do
		touch "$test_data_dir"/packages/"$package"/groups/"$group"
	done
}

function TestInstallPackage() {
	local package=$1
	local inst_as=$2

	local kind
	kind=$(cat "$test_data_dir"/packages/"$package"/kind)

	printf '%s\t%s\t%s\n' "$package" "$kind" "$inst_as" >> "$test_data_dir"/packages.txt

	local path
	find "$test_data_dir"/packages/"$package"/files -mindepth 1 -maxdepth 1 -print0 | \
		while read -r -d $'\0' path
		do
			cp -a "$path" "$test_data_dir"/files/
		done
}

function TestExpectPacManLog() {
	touch "$test_data_dir"/pacman.log
	diff -u /dev/stdin <( sed -E 's/^pacman (--noconfirm )?//g' "$test_data_dir"/pacman.log )
}
