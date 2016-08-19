#!/bin/zsh
set -eu

IFS=$'\n'

CONFIG_DIR=config

mkdir -p "$CONFIG_DIR"

function aconf-compile {
	PACKAGES=()

	for FILE in "$CONFIG_DIR"/*.sh(N)
	do
		echo "Sourcing $FILE..."
		source "$FILE"
	done

	PACKAGES=($(IFS=' ' echo "$PACKAGES" | sort | uniq))
}

echo "Querying package list..."
INSTALLED_PACKAGES=$(pacman --query --quiet --explicit --native | sort)
