#!/bin/bash
# Wrapper script used to call aurweb-git-auth externally when
# utilizing a Poetry-based virtualenv.
# Based on examples/aurweb-git-auth.sh and docker/git-entrypoint.sh from aurweb v6.2.3

# Debug logging
exec 2>>/tmp/aurweb-git-auth-debug.log
echo "=== $(date) ===" >&2
echo "Args: $*" >&2
echo "User: $(id)" >&2
echo "HOME: $HOME" >&2
echo "AUR_CONFIG: $AUR_CONFIG" >&2
echo "PWD before cd: $PWD" >&2

# Set HOME if not set (SSH AuthorizedKeysCommand may not provide it)
if [[ -z "$HOME" ]]; then
	export HOME="/opt/aur"
	echo "HOME was not set, set to: $HOME" >&2
fi

export AUR_CONFIG="/etc/aurweb/config"
aurweb_dir="/opt/aur/aurweb"
cd "$aurweb_dir" || { echo "Failed to cd to $aurweb_dir" >&2; exit 1; }
echo "PWD after cd: $PWD" >&2

# Test if poetry works at all
echo "Testing poetry --version:" >&2
poetry --version >&2 2>&1 || echo "Poetry version check failed with code $?" >&2

# Test if poetry env info works
echo "Testing poetry env info:" >&2
poetry env info >&2 2>&1 || echo "Poetry env info failed with code $?" >&2

# Get the virtualenv path from poetry
venv_path=$(poetry env info -p 2>/dev/null)
echo "Virtualenv path: $venv_path" >&2

if [[ -n "$venv_path" && -f "$venv_path/bin/python" ]]; then
	# Test if the module can be imported
	echo "Testing if aurweb.git.auth module can be imported:" >&2
	"$venv_path/bin/python" -c "import aurweb.git.auth; print('Module imported successfully')" >&2 2>&1 || echo "Module import failed" >&2

	# First, test with the absolute simplest Python script
	echo "Testing if Python can print to stderr:" >&2
	"$venv_path/bin/python" -c "import sys; sys.stderr.write('PYTHON STDERR TEST\n'); sys.stderr.flush()" 2>&1 >&2 || echo "Python stderr test failed" >&2

	# Try calling aurweb-git-auth entry point directly
	echo "Trying to call aurweb-git-auth entry point directly from venv:" >&2
	if [[ -f "$venv_path/bin/aurweb-git-auth" ]]; then
		echo "Found entry point at $venv_path/bin/aurweb-git-auth" >&2
		# Capture Python's output to a separate file
		python_output_file="/tmp/aurweb-git-auth-python-output.log"
		"$venv_path/bin/aurweb-git-auth" "$@" >"$python_output_file" 2>&1
		rc=$?
		echo "Entry point exit code: $rc" >&2
		echo "Python output captured to $python_output_file:" >&2
		cat "$python_output_file" >&2 2>/dev/null || echo "(no output)" >&2
		# If exit code is 0, output the captured stdout to our stdout
		if [[ $rc -eq 0 ]]; then
			cat "$python_output_file"
		fi
		exit $rc
	else
		echo "No entry point found at $venv_path/bin/aurweb-git-auth, trying Python module..." >&2
		python_output_file="/tmp/aurweb-git-auth-python-output.log"
		"$venv_path/bin/python" -m aurweb.git.auth "$@" >"$python_output_file" 2>&1
		rc=$?
		echo "Python module exit code: $rc" >&2
		echo "Python output captured to $python_output_file:" >&2
		cat "$python_output_file" >&2 2>/dev/null || echo "(no output)" >&2
		if [[ $rc -eq 0 ]]; then
			cat "$python_output_file"
		fi
		exit $rc
	fi
else
	echo "Could not find virtualenv Python, falling back to poetry run" >&2
	output=$(poetry run aurweb-git-auth "$@" 2>&1)
	rc=$?
	echo "Poetry run output: $output" >&2
	echo "Exit code: $rc" >&2
	if [[ $rc -eq 0 ]]; then
		echo "$output"
	fi
	exit $rc
fi
