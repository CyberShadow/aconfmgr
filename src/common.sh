#!/bin/bash
# (for shellcheck)

IFS=$'\n'

config_dir=config
output_dir=output
system_dir=system # Current system configuration, to be compared against the output directory
tmp_dir=tmp

config_save_target=$config_dir/99-unsorted.sh

ignore_paths=(
    '/dev'
    '/home'
    '/mnt'
    '/proc'
    '/root'
    '/run'
    '/sys'
    '/tmp'
    # '/var/.updated'
    '/var/cache'
    # '/var/lib'
    # '/var/lock'
    # '/var/log'
    # '/var/spool'
)

mkdir -p "$config_dir"

function AconfCompile() {

	# Configuration

	rm -rf "$output_dir"
	mkdir "$output_dir"
	touch "$output_dir"/packages.txt
	touch "$output_dir"/foreign-packages.txt
	touch "$output_dir"/file-props.txt

	for file in "$config_dir"/*.sh
	do
		printf "Sourcing %s...\n" "$file"
		source "$file"
	done

	# System

	rm -rf "$system_dir"
	mkdir "$system_dir"

	echo "Querying package list..."
	pacman --query --quiet --explicit --native  | sort > "$system_dir"/packages.txt
	pacman --query --quiet --explicit --foreign | sort > "$system_dir"/foreign-packages.txt

	# Vars

	                  packages=($(< "$output_dir"/packages.txt sort --unique))
	        installed_packages=($(< "$system_dir"/packages.txt sort --unique))

	          foreign_packages=($(< "$output_dir"/foreign-packages.txt sort --unique))
	installed_foreign_packages=($(< "$system_dir"/foreign-packages.txt sort --unique))
}
