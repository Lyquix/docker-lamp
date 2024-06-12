#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
	printf "This script must be run as root!\n"
	exit
fi

# Check if the script is being run in Docker
if ! grep -q docker /proc/1/cgroup; then
	printf "This script must be run in the Docker terminal\n"
	exit
fi

DIVIDER="\n***************************************\n\n"
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export NEEDRESTART_MODE=a

printf "Install MySQL...\n"
PCKGS=("mysql-server" "mysql-client")
apt-fast -y -qq --no-install-recommends install ${PCKGS[@]}

# MySQL
printf $DIVIDER
printf "MYSQL\n"
printf "The script will update MySQL and setup intial databases\n"

if [ ! -f /etc/mysql/mysql.conf.d/mysqld.cnf.orig ]; then
	printf "Backing up my.cnf configuration file to /etc/mysql/mysql.conf.d/mysqld.cnf.orig\n"
	cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.orig
fi

printf "Updating configuration\n"

FIND="^\s*key_buffer\s*=\s*.*"
REPLACE="key_buffer=16M"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*max_allowed_packet\s*=\s*.*"
REPLACE="max_allowed_packet=16M"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*thread_stack\s*=\s*.*"
REPLACE="thread_stack=192K"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*thread_cache_size\s*=\s*.*"
REPLACE="thread_cache_size=8"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*#\s*table_cache\s*=\s*.*" # commented by default
REPLACE="table_cache=64"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*#\s*log_slow_queries\s*=\s*.*" # commented by default
REPLACE="log_slow_queries = /var/log/mysql/mysql-slow.log"
printf "my.cnf: $REPLACE\n"
REPLACE=${REPLACE//\//\\\/} # Escape the / characters
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

FIND="^\s*#\s*long_query_time\s*=\s*.*" # commented by default
REPLACE="long_query_time=1"
printf "my.cnf: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/mysql/mysql.conf.d/mysqld.cnf

# Set the home directory for the mysql user
usermod -d /var/lib/mysql/ mysql
chown -R mysql:mysql /var/lib/mysql

# Restart MySQL
service mysql stop
killall -9 mysqld mysqld_safe
rm -rf /run/mysqld/*
service mysql start

# Create dbuser
mysql -u root -e "CREATE USER 'dbuser'@localhost IDENTIFIED BY 'dbpassword'; GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@localhost;"
printf "You can connect to the database with\n\tuser: dbuser\n\tpassword: dbpassword\n"


# Regenerate VirtualHost files
printf $DIVIDER
printf "Regenerate VirtualHost files\n"
/srv/www/regen-vhosts.sh

# Create a lock file
touch /lamp-setup-first-boot.lock

exit