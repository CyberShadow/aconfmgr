#!/bin/zsh
set -eu

IFS=$'\n'

CONFIG_DIR=config
OUTPUT_DIR=output
SYSTEM_DIR=system # Current system configuration, to be compared against the output directory

CONFIG_SAVE_TARGET=$CONFIG_DIR/99-unsorted.sh

mkdir -p "$CONFIG_DIR"

function aconf-compile {

	# Configuration

	rm -rf "$OUTPUT_DIR"
	mkdir "$OUTPUT_DIR"
	touch "$OUTPUT_DIR"/packages.txt
	touch "$OUTPUT_DIR"/file-props.txt

	for FILE in "$CONFIG_DIR"/*.sh(N)
	do
		echo "Sourcing $FILE..."
		source "$FILE"
	done


	# System

	rm -rf "$SYSTEM_DIR"
	mkdir "$SYSTEM_DIR"

	echo "Querying package list..."
	pacman --query --quiet --explicit --native | sort > "$SYSTEM_DIR"/packages.txt

	# Vars

	PACKAGES=($(cat "$OUTPUT_DIR"/packages.txt | sort --unique))
	INSTALLED_PACKAGES=($(cat "$SYSTEM_DIR"/packages.txt | sort --unique))
}
