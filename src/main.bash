# main.bash

# This file contains aconfmgr's entry point.

aconfmgr_version=0.0.0

# shellcheck source=common.bash
source "$src_dir"/common.bash
# shellcheck source=save.bash
source "$src_dir"/save.bash
# shellcheck source=apply.bash
source "$src_dir"/apply.bash
# shellcheck source=check.bash
source "$src_dir"/check.bash
# shellcheck source=diff.bash
source "$src_dir"/diff.bash
# shellcheck source=helpers.bash
source "$src_dir"/helpers.bash

function Usage() {
	printf 'aconfmgr v%s\n' "${aconfmgr_version}"
	printf 'Written by Vladimir Panteleev <aconfmgr@thecyber%s.net>\n' "shadow"
	printf 'https://github.com/CyberShadow/aconfmgr\n'
	echo
	printf 'Usage:  %s [OPTIONS]... ACTION\n' "$0"
	echo
	printf 'Supported actions:\n'
	printf '  save    Update the configuration to reflect the current state of the system\n'
	printf '  apply   Update the system to reflect the current contents of the configuration\n'
	printf '  check   Syntax-check and lint the configuration\n'
	printf '  diff    Compare configuration and system\n'
	echo
	printf 'Supported options:\n'
	printf '  -h, --help               Print this message\n'
	printf '  -c, --config DIR         Set the path to your configuration directory\n'
	printf '      --skip-config        Skip the configuration parsing step\n'
	printf '                           (reuse previous results)\n'
	printf '      --skip-inspection    Skip the system inspection step\n'
	printf '                           (reuse previous results)\n'
	printf '      --skip-checksums     Skip checksum verification of installed packages\n'
	printf '                           (faster and generally safe,\n'
	printf '                            but may miss changes in exceptional circumstances)\n'
	printf '      --aur-helper HELPER  Set AUR helper to use for installing foreign packages\n'
	printf '      --color WHEN         When to use colors in output (always/auto/never)\n'
	printf '      --paranoid           Always prompt before making any changes to the system\n'
	printf '      --yes                Never prompt before making any changes to the system\n'
	printf '  -v, --verbose            Show progress with additional detail\n'
	echo
	printf 'For more information, please refer to the full documentation at:\n'
	printf 'https://github.com/CyberShadow/aconfmgr#readme\n'
}

function UsageError() {
	Usage
	echo
	# shellcheck disable=SC2059
	printf "$@"
	echo
	Exit 2
}

function Main() {
	local color=

	while [[ $# != 0 ]]
	do
		case "$1" in
			save|apply|check|diff)
				if [[ -n "$aconfmgr_action" ]]
				then
					UsageError "An action has already been specified"
				fi

				aconfmgr_action="$1"
				shift

				if [[ "$aconfmgr_action" == diff ]]
				then
					aconfmgr_action_args=("$@")
					break
				fi
				;;
			-h|--help|help)
				Usage
				Exit 0
				;;
			-c|--config)
				config_dir="$2"
				shift 2
				;;
			--skip-config)
				skip_config=y
				shift
				;;
			--skip-inspection)
				skip_inspection=y
				shift
				;;
			--skip-checksums)
				skip_checksums=y
				shift
				;;
			--aur-helper)
				aur_helper="$2"
				shift 2
				;;
			--color)
				color="$2"
				shift 2
				;;
			--paranoid)
				if [[ $prompt_mode != normal ]]
				then
					UsageError "A prompt mode has already been specified"
				fi
				prompt_mode=paranoid
				pacman_opts+=(--confirm)
				yaourt_opts+=(--confirm)
				shift
				;;
			--yes)
				if [[ $prompt_mode != normal ]]
				then
					UsageError "A prompt mode has already been specified"
				fi
				prompt_mode=never
				pacman_opts+=(--noconfirm)
				aurman_opts+=(--noconfirm --noedit --skip_news)
				pacaur_opts+=(--noconfirm --noedit)
				yaourt_opts+=(--noconfirm)
				yay_opts+=(--noconfirm)
				paru_opts+=(--noconfirm)
				makepkg_opts+=(--noconfirm)
				shift
				;;
			-v|--verbose)
				verbose=$((verbose+1))
				shift
				;;
			*)
				UsageError "Unrecognized option: %s" "$1"
				;;
		esac
	done

	case "$color" in
		always)
			pacman_opts+=(--color always)
			aurman_opts+=(--color always)
			pacaur_opts+=(--color always)
			yaourt_opts+=(--color)
			yay_opts+=(--color always)
			paru_opts+=(--color always)
			diff_opts+=('--color=always')
		;;
		never)
			DisableColor
			pacman_opts+=(--color never)
			aurman_opts+=(--color never)
			pacaur_opts+=(--color never)
			yaourt_opts+=(--nocolor)
			yay_opts+=(--color never)
			paru_opts+=(--color never)
			makepkg_opts+=(--nocolor)
			diff_opts+=('--color=never')
			;;
		auto)
			[ -t 1 ] || DisableColor
			pacman_opts+=(--color auto)
			aurman_opts+=(--color auto)
			pacaur_opts+=(--color auto)
			yay_opts+=(--color auto)
			paru_opts+=(--color auto)
			;;
		'')
			[ -t 1 ] || DisableColor
			;;
		*)
			UsageError "Unrecognized --color value: %s" "$color"
			;;
	esac

	case "$aconfmgr_action" in
		save)
			AconfSave
			;;
		apply)
			AconfApply
			;;
		check)
			AconfCheck
			;;
		diff)
			AconfDiff
			;;
		*)
			Usage
			Exit 2
			;;
	esac

	Exit
}

Main "$@"
