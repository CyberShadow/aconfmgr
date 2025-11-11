#!/usr/bin/env bash
set -eEuo pipefail

if [[ ! -v ACONFMGR_IN_CONTAINER ]]
then
	echo 'Refusing to start outside Docker.'
	exit 1
fi

{
	echo 'Starting mysql ...'
	/usr/bin/mysqld \
		--user=aur \
		--datadir=/opt/aur/mysql \
		--socket=/opt/aur/run/mysqld.sock \
		--skip-networking \
		--general-log \
		--skip-log-bin \
		--innodb-use-native-aio=OFF &

	while [[ ! -e /opt/aur/run/mysqld.sock ]]
	do
		echo 'Waiting for mysql ...'
		sleep 1
	done

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[mysql] /' & }

{
	echo 'Starting aurweb ASGI server (gunicorn) ...'
	su aur -s /bin/bash -c 'cd /opt/aur/aurweb && poetry run gunicorn --bind 127.0.0.1:8000 --forwarded-allow-ips "*" --workers 2 -k uvicorn.workers.UvicornWorker aurweb.asgi:app' &

	# Wait for server to be ready
	for i in {1..30}; do
		if curl -s http://127.0.0.1:8000/ > /dev/null 2>&1; then
			break
		fi
		sleep 1
	done

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[aurweb] /' & }

{
	echo 'Starting fcgiwrap ...'
	rm -f /opt/aur/run/fcgiwrap.sock
	su aur -s /bin/sh -c '/usr/sbin/fcgiwrap -s unix:/opt/aur/run/fcgiwrap.sock' &

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[fcgiwrap] /' & }

{
	echo 'Starting nginx ...'
	/usr/bin/nginx -g 'error_log stderr;' -c /opt/aur/nginx.conf

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[nginx] /' & }

{
	echo 'Starting sshd ...'
	/usr/bin/sshd -e -f /opt/aur/sshd_config

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[sshd] /' & }

echo 'All ready!'

if [[ $$ -eq 1 ]] # pid1 ?
then
	if [ -t 0 ]
	then
		# Run an interactive shell (for debugging), which also keeps the container running.
		/bin/bash
	else
		# Keep container open
		sleep infinity
	fi
fi
