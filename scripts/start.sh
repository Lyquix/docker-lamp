#!/bin/bash

# Check if --no-sudo was passed
NO_SUDO=0
for PARAM in "$@"; do
	if [ "$PARAM" = "--no-sudo" ]; then
		NO_SUDO=1
	fi
done

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
	printf "This script must be run as root!\n"
	if [ $NO_SUDO -eq 0 ]; then
		exec sudo /bin/bash "$0" "$@" --no-sudo
	fi
	exit
fi

# Check if the script is being run in Docker
if ! grep -q docker /proc/1/cgroup; then
	printf "This script must be run in the Docker terminal\n"
	exit
fi

# Function to check if a directory is mounted
function check_directory_mounted {
	while true; do
		# Check if the target directory is mounted
		MOUNTED=$(mount | grep "$1")
		if [ "$MOUNTED" ]; then
			echo "$1 is MOUNTED"
			break
		else
			echo "$1 is not mounted yet, waiting 5 seconds..."
			sleep 5
		fi
	done
}
check_directory_mounted "/srv/www"
check_directory_mounted "/etc/apache2/sites-available"
check_directory_mounted "/var/lib/mysql"

# Apache
if service --status-all | grep -wq apache2; then
	echo "Apache2 is installed"
	service apache2 status
	service apache2 stop
	service apache2 start
	service apache2 status
else
	echo "Apache2 is not installed"
fi

# PHP-FPM
for VERSION in 7.2 7.4 8.1 8.3; do
	if service --status-all | grep -wq "php$VERSION-fpm"; then
		echo "PHP-FPM $VERSION is installed"
		service "php$VERSION-fpm" status
		service "php$VERSION-fpm" stop
		service "php$VERSION-fpm" start
		service "php$VERSION-fpm" status
	else
		echo "PHP-FPM $VERSION is not installed"
	fi
done

# MySQL
if service --status-all | grep -wq mysql; then
	echo "MySQL is installed"
	service mysql status
	service mysql stop

	# Kill any existing mysqld process
	killall -9 mysqld

	# Remove any previous sockets and lock files
	rm -f /run/mysqld/mysql*

	service mysql start
	service mysql status
else
	echo "MySQL is not installed"
fi

# Prevent the container from exiting by tailing a log file
tail -f /var/log/apache2/access.log
