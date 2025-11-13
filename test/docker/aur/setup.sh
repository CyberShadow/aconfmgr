#!/usr/bin/env bash
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

echo 'Creating database and setting up permissions ...'
/usr/bin/mysql \
	--socket=/opt/aur/run/mysqld.sock \
	<<-'EOF'
	DROP DATABASE IF EXISTS AUR;
	CREATE DATABASE AUR;
	-- Fix MariaDB 11.x authentication for aur user
	-- Testing: Removed unix_socket authentication to see if it's necessary
	-- ALTER USER 'aur'@'localhost' IDENTIFIED VIA unix_socket;
	GRANT ALL PRIVILEGES ON AUR.* TO 'aur'@'localhost';
	FLUSH PRIVILEGES;
	EOF

echo 'Initializing database with aurweb.initdb ...'

# aurweb v6.x uses aurweb.initdb instead of SQL file
# Use poetry to run in the aurweb source directory where dependencies are available
# Run as aur user since unix_socket authentication requires matching OS and MySQL usernames
# Install aurweb itself (not just dependencies) to make entry points like aurweb-git-auth available
# Testing: Changed from 'su -s /bin/bash aur' to 'sudo -u aur bash' to see if su is necessary
sudo -u aur bash <<-'AUREOF'
	cd /opt/aur/aurweb
	poetry env use python3.12
	# poetry.lock is already in sync with pyproject.toml (generated during package build)
	# Testing: Changed from 'poetry install --only main' to see if dev dependencies are needed
	poetry install
	poetry run python -m aurweb.initdb
	AUREOF

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

	# Generate CA certificate with keyUsage extension (required by Python 3.13)
	openssl genpkey -algorithm RSA -out ca.key
	openssl req -x509 -key ca.key -out ca.crt \
			-subj "/CN=$org/O=$org" \
			-addext "keyUsage = critical, keyCertSign, cRLSign" \
			-addext "basicConstraints = critical, CA:TRUE"

	# Generate site certificate with keyUsage extension (required by Python 3.13)
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
				keyUsage = critical, digitalSignature, keyEncipherment
				extendedKeyUsage = serverAuth
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
