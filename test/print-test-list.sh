#!/bin/bash
set -eEuo pipefail
shopt -s lastpipe

# Prints the list of tests which should be executed in the current CI invocation.
# By default, that is all tests.

if [[ ! -v ACONFMGR_CI_SHARD ]]
then
	ACONFMGR_CI_SHARD=0
fi
if [[ ! -v ACONFMGR_CI_TOTAL_SHARDS ]]
then
	ACONFMGR_CI_TOTAL_SHARDS=1
fi

# Use the "greedy number partitioning" algorithm for this multiway
# number partitioning problem to distribute tests across shards.

# Cumulative durations for shards so far
shard_durations=()
for (( shard=0; shard < ACONFMGR_CI_TOTAL_SHARDS; shard++ ))
do
	shard_durations+=(0)
done

# Generated by util/parse_test_times.sh
declare -A test_durations
test_durations=(
	[t-0_sample]=60830600
	[t-1_save-0_empty]=5323811800
	[t-1_save-1_packages-1_new]=18448578200
	[t-1_save-1_packages-2_missing]=5315925800
	[t-1_save-1_packages-3_ignore]=8408050300
	[t-1_save-2_files-1_stray-1_file]=5441335300
	[t-1_save-2_files-1_stray-2_empty-1_simple]=5384498500
	[t-1_save-2_files-1_stray-3_dir]=5360614600
	[t-1_save-2_files-1_stray-4_link]=5384625900
	[t-1_save-2_files-1_stray-5_dirfile]=5392469300
	[t-1_save-2_files-1_stray-6_props]=5388267900
	[t-1_save-2_files-2_modified-1_props]=8535842800
	[t-1_save-2_files-2_modified-2_skipchecksums_hitdiffsize]=5426512500
	[t-1_save-2_files-2_modified-3_skipchecksums_hitdiffmtime]=5435748400
	[t-1_save-2_files-2_modified-4_skipchecksums_miss]=5328010300
	[t-1_save-2_files-2_modified-5_filter]=5378989300
	[t-1_save-2_files-3_extra-1_file]=5364143100
	[t-1_save-2_files-3_extra-2_props]=5435528500
	[t-1_save-2_files-4_ignored-1_simple]=5336832100
	[t-1_save-2_files-4_ignored-2_shellpatterns]=6078909200
	[t-1_save-2_files-4_ignored-3_shellpatterns_intl]=5401712900
	[t-1_save-3_skipinspection]=5543430200
	[t-1_save-4_skipconfig]=10397476600
	[t-2_apply-0_empty]=5451313500
	[t-2_apply-1_packages-1_new]=8553041000
	[t-2_apply-1_packages-2_missing]=8584368500
	[t-2_apply-1_packages-3_unpinned]=8501603300
	[t-2_apply-1_packages-4_orphan]=16819812100
	[t-2_apply-1_packages-5_ignore]=8403336300
	[t-2_apply-1_packages-6_aur-1_makepkg-1_normal]=13823490200
	[t-2_apply-1_packages-6_aur-1_makepkg-2_root]=18296150000
	[t-2_apply-1_packages-6_aur-1_makepkg-3_basedevel]=18946955400
	[t-2_apply-1_packages-6_aur-1_makepkg-4_split]=45123542100
	[t-2_apply-1_packages-6_aur-1_makepkg-5_dependencies]=27368418700
	[t-2_apply-1_packages-6_aur-1_makepkg-6_provider]=17866797700
	[t-2_apply-1_packages-6_aur-1_makepkg-7_helperfirst]=61258993700
	[t-2_apply-1_packages-6_aur-2_helpers-1_makepkg]=21681121500
	[t-2_apply-1_packages-6_aur-2_helpers-2_pacaur]=73970403100
	[t-2_apply-1_packages-6_aur-2_helpers-3_yaourt]=38606179400
	[t-2_apply-1_packages-6_aur-2_helpers-4_aurman]=34734918200
	[t-2_apply-1_packages-6_aur-2_helpers-5_yay]=58528933700
	[t-2_apply-1_packages-6_aur-2_helpers-6_paru]=442958765200
	[t-2_apply-1_packages-9_matrix]=460379586400
	[t-2_apply-2_files-1_stray-1_new-1_file]=5396847800
	[t-2_apply-2_files-1_stray-1_new-2_dir]=5422814100
	[t-2_apply-2_files-1_stray-1_new-3_link]=5480735500
	[t-2_apply-2_files-1_stray-1_new-4_props]=5500834300
	[t-2_apply-2_files-1_stray-1_new-5_filter]=5514198400
	[t-2_apply-2_files-1_stray-2_modified-1_file]=5659705800
	[t-2_apply-2_files-1_stray-2_modified-2_dirfile]=5651780200
	[t-2_apply-2_files-1_stray-3_extra-1_file]=5599854800
	[t-2_apply-2_files-1_stray-3_extra-2_props]=5653537500
	[t-2_apply-2_files-1_stray-3_extra-3_dir]=5631574000
	[t-2_apply-2_files-1_stray-3_extra-4_dir_nonempty]=5573875100
	[t-2_apply-2_files-1_stray-4_old-1_filter]=5575134500
	[t-2_apply-2_files-2_owned-1_new-1_priority]=5489673500
	[t-2_apply-2_files-2_owned-2_modified-1_file]=5540120300
	[t-2_apply-2_files-2_owned-2_modified-2_props]=8896206900
	[t-2_apply-2_files-2_owned-2_modified-3_priority]=8800007500
	[t-2_apply-2_files-2_owned-2_modified-4_editgone]=8406021600
	[t-2_apply-2_files-2_owned-2_modified-5_atomic]=8713903300
	[t-2_apply-2_files-2_owned-2_modified-6_access]=9016978300
	[t-2_apply-2_files-2_owned-3_delete-1_file]=8726305800
	[t-2_apply-2_files-2_owned-3_delete-2_dir]=8695303900
	[t-2_apply-2_files-2_owned-4_restore-1_deleted-1_file]=8917928700
	[t-2_apply-2_files-2_owned-4_restore-1_deleted-2_dirfile]=9064213500
	[t-2_apply-2_files-2_owned-4_restore-2_modified]=9510575300
	[t-2_apply-2_files-9_matrix]=19003219400
	[t-3_roundtrip-1_packages-9_matrix]=467555871500
	[t-3_roundtrip-2_files-1_extra-1_dir]=10581818900
	[t-3_roundtrip-2_files-9_matrix]=18499747900
	[t-4_lint-0_empty]=93719300
	[t-4_lint-1_ok]=101154400
	[t-4_lint-2_unused_file]=698691100
	[t-5_helpers-1_copyfile_relative_path]=110747800
	[t-5_helpers-2_getpackageoriginalfile-1_reg]=8909734800
	[t-5_helpers-2_getpackageoriginalfile-2_sudo]=8920780700
	[t-5_helpers-3_removepackage]=5409231900
	[t-5_helpers-4_removefile]=5458596700
	[t-5_helpers-5_addpackagegroup]=8870910400
	[t-5_helpers-6_aconfneedprogram]=16230768800
	[t-6_diff-0_empty]=5195147500
	[t-6_diff-1_lost]=5345148000
	[t-6_diff-2_owned-1_edit]=8777857900
	[t-6_diff-2_owned-2_revert]=9072484700
)

# Fill in placeholder durations for missing tests
find t -name 't-*.sh' -printf '%f\n' |
	sed 's/\.sh$//' |
	while IFS= read -r test_name
	do
		if [[ ! -v test_durations["$test_name"] ]]
		then
			printf 'Duration not known for test %q, please add to print-test-list.sh\n' "$test_name" 1>&2
			test_durations[$test_name]=0
		fi
	done

for test_name in "${!test_durations[@]}"
do
	printf '%d\t%s\n' "${test_durations[$test_name]}" "$test_name"
done |
	sort -rn |
	while read -r duration test_name
	do
		best_shard=0
		for (( shard=0; shard < ACONFMGR_CI_TOTAL_SHARDS; shard++ ))
		do
			if [[ "${shard_durations[$shard]}" -lt "${shard_durations[$best_shard]}" ]]
			then
				best_shard=$shard
			fi
		done

		shard_durations[$best_shard]=$((shard_durations[best_shard]+duration))
		if [[ $best_shard -eq $ACONFMGR_CI_SHARD ]]
		then
			printf '%s\n' "$test_name"
		fi
	done |
	sort
