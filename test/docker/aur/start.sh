#!/bin/bash
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
		--skip-log-bin &

	while [[ ! -e /opt/aur/run/mysqld.sock ]]
	do
		echo 'Waiting for mysql ...'
		sleep 1
	done

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[mysql] /' & }

{
	echo 'Starting php-fpm ...'
	/usr/sbin/php-fpm --fpm-config /opt/aur/php-fpm.conf --php-ini /opt/aur/php.ini

	echo 'Ready'
} 2>&1 | { sed -u 's/^/[php-fpm] /' & }

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
