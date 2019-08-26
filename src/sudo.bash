# sudo.bash

# This file contains the sudo server and helpers.

# The default sudo configuration closes all file descriptors above 3,
# leaving only stdin/stdout/stderr. However, at the same time, sudo
# itself (or the PAM modules it uses) can write to standard output,
# and conceivably read from standard input. This makes it impossible
# to know with certainty whether any data on sudo stdout is coming
# from the executed program, or sudo itself.

# Work around this problem by spawning a sudo server, and
# communicating with it using fifos.

# Utility function

function AconfMkFifo() {
	local path=$1

	rm -f "$path"
	mkfifo -m 600 "$path"
	if [[ $EUID == 0 && -v SUDO_UID && -v SUDO_GID ]]
	then
		chown "$SUDO_UID:$SUDO_GID" "$path"
	fi
}

# The actual sudo server.
# Executed as root.
function AconfSudoServer() {
	aconf_fifo_dir=$1

	local aconf_sudo_input
	exec {aconf_sudo_input}< "$aconf_fifo_dir"/sudo-server-input
	rm "$aconf_fifo_dir"/sudo-server-input # no more readers or writers after this

	local ticket=0
	local command
	{
		printf t # Implied first command which caused the sudo server to start
		cat <&$aconf_sudo_input
	} | \
		while read -r -n 1 command
		do
			AconfMkFifo "$aconf_fifo_dir"/sudo-"$ticket"-meta
			AconfMkFifo "$aconf_fifo_dir"/sudo-"$ticket"-input
			AconfMkFifo "$aconf_fifo_dir"/sudo-"$ticket"-output
			AconfMkFifo "$aconf_fifo_dir"/sudo-"$ticket"-error
			{
				local argc argi argv=()
				{
					read -r -d $'\0' argc
					for ((argi = 0; argi < argc; argi++))
					do
						local arg
						read -r -d $'\0' arg
						argv+=("$arg")
					done
				} < "$aconf_fifo_dir"/sudo-"$ticket"-meta

				local status=0
				"${argv[@]}" \
					<   "$aconf_fifo_dir"/sudo-"$ticket"-input \
					>>  "$aconf_fifo_dir"/sudo-"$ticket"-output \
					2>> "$aconf_fifo_dir"/sudo-"$ticket"-error \
					|| status=$?
				printf '%d\0' "$status" >> "$aconf_fifo_dir"/sudo-"$ticket"-meta
			} &
			printf '%d\0' "$ticket" >> "$aconf_fifo_dir"/sudo-server-output
			ticket=$((ticket+1))
		done
}

# No fancy sudo support needed if we are already root.  Just ensure
# that we can start the sudo server (by leaving the declarations above
# visible in root mode too).
if [[ $EUID == 0 ]]
then
	function sudo() { "$@" ; }
	function AconfSudoInit() { : ; }
	return
fi

aconf_self=$0

# Wait until the first sudo request to start the sudo server.
# Run this from top-level, so it still has the original stdout etc.
function AconfSudoServerTrampoline() {
	# Wait until the first sudo request
	local command
	if read -r -n 1 command < "$aconf_fifo_dir"/sudo-server-input
	then
		Log 'Starting sudo server.\n'
		exec sudo "$aconf_self" sudo-server "$aconf_fifo_dir"
	fi
}

function AconfSudoInit() {
	if [[ -v aconf_fifo_dir ]]
	then
		# Some test cases may cause this function to be called more than once.
		return
	fi

	mkdir -p "$tmp_dir"
	aconf_fifo_dir=$(cd "$tmp_dir" && pwd)
	AconfMkFifo "$aconf_fifo_dir"/sudo-server-input
	AconfMkFifo "$aconf_fifo_dir"/sudo-server-output

	AconfSudoServerTrampoline &

	exec {aconf_sudo_input}> "$aconf_fifo_dir"/sudo-server-input
}

function sudo() {
	# Ping server, request ticket
	printf t >&$aconf_sudo_input

	# Read ticket
	local ticket
	read -r -d $'\0' ticket < "$aconf_fifo_dir"/sudo-server-output

	# Send args
	{
		printf '%d\0' $#
		printf '%s\0' "$@"
	} >> "$aconf_fifo_dir"/sudo-"$ticket"-meta

	local cat0 cat1 cat2
	cat >> "$aconf_fifo_dir"/sudo-"$ticket"-input <&0 &
	cat0=$!
	cat < "$aconf_fifo_dir"/sudo-"$ticket"-output >&1 &
	cat1=$!
	cat < "$aconf_fifo_dir"/sudo-"$ticket"-error >&2 &
	cat2=$!

	local status
	read -r -d $'\0' status < "$aconf_fifo_dir"/sudo-"$ticket"-meta

	if [ -t 0 ]
	then
		kill "$cat0"
		wait "$cat0" || true
	else
		wait "$cat0"
	fi

	wait "$cat1"
	wait "$cat2"
	return "$status"
}
