#!/bin/bash
# shellcheck disable=SC2031
source ./lib.bash

# Full matrix test for files.

TestPhase_Setup ###############################################################

LogEnter 'Expanding specs...\n'
# shellcheck disable=SC2191
specs=("
	"ignored={0..1}"
	"priority={0..1}"

	"f_present={0..1}"
	"f_kind={1..3}"
	"f_content={1..1}"
	"f_attr={1..1}"

	"p_present={0..2}"
	"p_kind={1..3}"
	"p_content={1..2}"
	"p_attr={1..2}"

	"c_present={0..1}"
	"c_kind={1..3}"
	"c_content={1..3}"
	"c_attr={1..3}"
")
LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

LogEnter 'Filtering specs...\n'
specs2=()
# shellcheck disable=SC2154
for spec in "${specs[@]}"
do
	eval "$spec"

	# Cull varying properties of absent files
	[[ "$f_present" != 0 || ( "$f_kind" == 1 && "$f_content" == 1 && "$f_attr" == 1 ) ]] || continue
	[[ "$p_present" != 0 || ( "$p_kind" == 1 && "$p_content" == 1 && "$p_attr" == 1 ) ]] || continue
	[[ "$c_present" != 0 || ( "$c_kind" == 1 && "$c_content" == 1 && "$c_attr" == 1 ) ]] || continue

	# Cull using "same" properties as absent objects
	if [[ "$f_present" == 0 && ( "$p_content" == 1 || "$p_attr" == 1 ) ]] ; then continue ; fi
	if [[ "$f_present" == 0 && ( "$c_content" == 1 || "$c_attr" == 1 ) ]] ; then continue ; fi
	if [[ "$p_present" == 0 && ( "$c_content" == 2 || "$c_attr" == 2 ) ]] ; then continue ; fi

	# Cull varying content for directories
	[[ "$f_kind" != 2 || "$f_content" == 1 ]] || continue
	[[ "$p_kind" != 2 || "$p_content" == 1 ]] || continue
	[[ "$c_kind" != 2 || "$c_content" == 1 ]] || continue

	fn="$ignored$priority-$f_present$f_kind$f_content$f_attr-$p_present$p_kind$p_content$p_attr-$c_present$c_kind$c_content$c_attr"

	specs2+=("$spec fn=$fn")
	unset spec ignored priority f_present f_kind f_content f_attr p_present p_kind p_content p_attr c_present c_kind c_content c_attr fn
done
specs=("${specs2[@]}")
unset specs2
LogLeave 'Done (%s specs).\n' "$(Color G "${#specs[@]}")"

file_kinds=(
	[1]=file
	[2]=dir
	[3]=link
)
file_modes=(
	[1]=766
	[2]=776
	[3]=777
)
file_users=(
	[1]=root
	[2]=billy
	[3]=nobody
)

LogEnter 'Creating package/config files...\n'
# shellcheck disable=SC2154
for spec in "${specs[@]}"
do
	eval "$spec"

	if ((ignored))
	then
		ignore_paths+=("/dir/$fn")
	fi

	if ((priority))
	then
		priority_files+=("/dir/$fn")
	fi

	if ((p_present))
	then
		[[ "$p_kind" != 2 ]] || p_content= # Directories may not have "content"
		TestAddFSObj test-package-"$p_present" "/dir/$fn" "${file_kinds[$p_kind]}" "$p_content" "${file_modes[$p_attr]}" "${file_users[$p_attr]}" "${file_users[$p_attr]}"
	fi

	if ((c_present))
	then
		case $c_kind in
			1) # file
				# shellcheck disable=SC2016
				TestAddConfig "$(printf 'printf %%s %q > $(CreateFile /dir/%q %q %q %q)' \
							  			"$c_content" "$fn" "${file_modes[$f_attr]}" "${file_users[$f_attr]}" "${file_users[$f_attr]}")"
				;;
			2) # dir
				TestAddConfig "$(printf 'CreateDir /dir/%q %q %q %q' \
							  			"$fn" "${file_modes[$c_attr]}" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
				;;
			3) # link
				TestAddConfig "$(printf 'CreateLink /dir/%q %q %q %q' \
							  			"$fn" "$c_content" "${file_users[$c_attr]}" "${file_users[$c_attr]}")"
				;;
		esac
	fi
	unset spec ignored priority f_present f_kind f_content f_attr p_present p_kind p_content p_attr c_present c_kind c_content c_attr fn
done
LogLeave

LogEnter 'Installing packages...\n'
TestAddPackage test-package-1 native explicit
TestAddPackage test-package-2 native explicit
TestAddConfig AddPackage test-package-2
LogLeave

LogEnter 'Creating filesystem files...\n'
# shellcheck disable=SC2154
for spec in "${specs[@]}"
do
	eval "$spec"

	if ((p_present))
	then
		TestDeleteFile "/dir/$fn"
	fi
	if ((f_present))
	then
		[[ "$f_kind" != 2 ]] || f_content= # Directories may not have "content"
		TestAddFSObj '' "/dir/$fn" "${file_kinds[$f_kind]}" "$f_content" "${file_modes[$f_attr]}" "${file_users[$f_attr]}" "${file_users[$f_attr]}"
	fi
	unset spec ignored priority f_present f_kind f_content f_attr p_present p_kind p_content p_attr c_present c_kind c_content c_attr fn
done
LogLeave

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################

# TODO

unset specs file_kinds file_modes file_users

TestDone ######################################################################
