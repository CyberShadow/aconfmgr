#!/bin/bash
# Wrapper script used to call aurweb-git-update as a git hook
# when utilizing a Poetry-based virtualenv.
# Based on aurweb-git-auth.sh wrapper pattern

# Debug logging
exec 2>>/tmp/aurweb-git-update-debug.log
echo "=== $(date) ===" >&2
echo "Args: $*" >&2
echo "User: $(id)" >&2
echo "HOME: $HOME" >&2
echo "AUR_CONFIG: $AUR_CONFIG" >&2
echo "PWD before cd: $PWD" >&2

# Set HOME if not set
if [[ -z "$HOME" ]]; then
	export HOME="/opt/aur"
	echo "HOME was not set, set to: $HOME" >&2
fi

export AUR_CONFIG="/etc/aurweb/config"
aurweb_dir="/opt/aur/aurweb"
cd "$aurweb_dir" || { echo "Failed to cd to $aurweb_dir" >&2; exit 1; }
echo "PWD after cd: $PWD" >&2

# Get the virtualenv path from poetry
venv_path=$(poetry env info -p 2>/dev/null)
echo "Virtualenv path: $venv_path" >&2

if [[ -n "$venv_path" && -f "$venv_path/bin/python" ]]; then
	# Try calling aurweb-git-update entry point directly from venv
	echo "Trying to call aurweb-git-update entry point from venv" >&2
	if [[ -f "$venv_path/bin/aurweb-git-update" ]]; then
		echo "Found entry point at $venv_path/bin/aurweb-git-update" >&2
		"$venv_path/bin/aurweb-git-update" "$@" 2>&1
		exit $?
	else
		echo "No entry point found, trying Python module..." >&2
		"$venv_path/bin/python" -m aurweb.git.update "$@" 2>&1
		exit $?
	fi
else
	echo "Could not find virtualenv, falling back to poetry run" >&2
	poetry run aurweb-git-update "$@" 2>&1
	exit $?
fi
