#!/bin/bash
# Wrapper script used to call aurweb-git-serve externally when
# utilizing a Poetry-based virtualenv.

# Set HOME if not set
if [[ -z "$HOME" ]]; then
	export HOME="/opt/aur"
fi

export AUR_CONFIG="/etc/aurweb/config"
aurweb_dir="/opt/aur/aurweb"
cd "$aurweb_dir" || { echo "Failed to cd to $aurweb_dir" >&2; exit 1; }

# Get the virtualenv path from poetry
venv_path=$(poetry env info -p 2>/dev/null)

if [[ -n "$venv_path" && -f "$venv_path/bin/python" ]]; then
	# Call aurweb-git-serve entry point directly from venv
	if [[ -f "$venv_path/bin/aurweb-git-serve" ]]; then
		exec "$venv_path/bin/aurweb-git-serve" "$@"
	else
		exec "$venv_path/bin/python" -m aurweb.git.serve "$@"
	fi
else
	# Fallback to poetry run
	exec poetry run aurweb-git-serve "$@"
fi
