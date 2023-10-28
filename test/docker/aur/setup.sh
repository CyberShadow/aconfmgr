#!/bin/bash
set -eEuo pipefail

if [[ ! -v ACONFMGR_IN_CONTAINER ]]
then
	echo 'Refusing to run setup outside Docker.'
	exit 1
fi

if [[ -f /opt/aur/initialized ]]
then
	return
fi

##### Git

echo 'Initializing git repository ...'
rm -rf /opt/aur/aurweb/aur.git
mkdir /opt/aur/aurweb/aur.git
(
	cd /opt/aur/aurweb/aur.git
	git init --bare .
	git config --local transfer.hideRefs '^refs/'
	git config --local --add transfer.hideRefs '!refs/'
	git config --local --add transfer.hideRefs '!HEAD'
	ln -s /usr/bin/aurweb-git-update hooks/update
)

##### MySQL

echo 'Initializing mysql database ...'
rm -rf /opt/aur/mysql
mysql_install_db --user=aur --basedir=/usr --datadir=/opt/aur/mysql

echo 'Starting mysql ...'
/usr/bin/mysqld \
	--user=aur \
	--datadir=/opt/aur/mysql \
	--socket=/opt/aur/run/mysqld.sock \
	--skip-networking \
	--general-log \
	--skip-log-bin &

while [ ! -e /opt/aur/run/mysqld.sock ]
do
	echo 'Waiting for mysql ...'
	sleep 1
done

echo 'Creating database ...'
/usr/bin/mysql \
	--socket=/opt/aur/run/mysqld.sock \
	<<-'EOF'
	DROP DATABASE IF EXISTS AUR;
	CREATE DATABASE AUR;
	EOF

echo 'Initializing database ...'

/usr/bin/mysql \
	--socket=/opt/aur/run/mysqld.sock \
	AUR \
	< /opt/aur/aurweb/schema/aur-schema.sql

echo 'Stopping MySQL ...'

/usr/bin/mysqladmin \
	--socket=/opt/aur/run/mysqld.sock \
	shutdown

##### SSL

echo 'Generating SSL certificate ...'

rm -rf /opt/aur/ssl
mkdir /opt/aur/ssl
(
	cd /opt/aur/ssl

	# Based on https://bbs.archlinux.org/viewtopic.php?pid=1776753#p1776753

	org=aconfmgr
	domain=aur.archlinux.org

	openssl genpkey -algorithm RSA -out ca.key
	openssl req -x509 -key ca.key -out ca.crt \
			-subj "/CN=$org/O=$org"

	openssl genpkey -algorithm RSA -out site.key
	openssl req -new -key site.key -out site.csr \
			-subj "/CN=$domain/O=$org"

	openssl x509 -req -in site.csr -days 365 -out site.crt \
			-CA ca.crt -CAkey ca.key -CAcreateserial \
			-extfile /dev/stdin \
			<<-END
				basicConstraints = CA:FALSE
				subjectKeyIdentifier = hash
				authorityKeyIdentifier = keyid,issuer
				subjectAltName = DNS:$domain
				END

	cat site.crt ca.crt > chain.crt

	echo 'Trusting CA certificate ...'
	trust anchor ca.crt
)

##### SSH

# Generate host keys, if absent
echo 'Generating missing SSH host keys ...'
ssh-keygen -A

# Unlock aur user, allowing log in via ssh
echo 'Unlocking aur user ...'
usermod -p '*' aur

##### Owner

echo 'Updating owner ...'
chown -R aur:aur /opt/aur

##### Done

touch /opt/aur/initialized
echo 'Done!'
