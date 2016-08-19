#!/bin/zsh
set -eu

IFS=$'\n'

CONFIG_DIR=config
OUTPUT_DIR=output

mkdir -p "$CONFIG_DIR"

function aconf-compile {
	rm -rf "$OUTPUT_DIR"
	mkdir "$OUTPUT_DIR"

	for FILE in "$CONFIG_DIR"/*.sh(N)
	do
		echo "Sourcing $FILE..."
		source "$FILE"
	done

	if [[ -f "$OUTPUT_DIR"/packages.txt ]]
	then
		PACKAGES=($(cat "$OUTPUT_DIR"/packages.txt | sort | uniq))
	else
		PACKAGES=()
	fi
}

echo "Querying package list..."
INSTALLED_PACKAGES=$(pacman --query --quiet --explicit --native | sort)
