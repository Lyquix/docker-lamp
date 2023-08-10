#!/bin/bash

# Check if --no-sudo was passed
NO_SUDO=0
for param in "$@"; do
	if [ "$param" = "--no-sudo" ]; then
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
		mounted=$(mount | grep "$1")
		if [ "$mounted" ]; then
			echo "$1 is mounted"
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

# Check if the script /lamp-setup.sh exists
if [[ -f "/lamp-setup.sh" ]]; then
	sleep 15
	rm /etc/apache2/sites-available/000-default.conf
	rm /etc/apache2/sites-available/default-ssl.conf
	chmod +x /lamp-setup.sh
	/lamp-setup.sh
	rm /lamp-setup.sh
fi

# Apache
if service --status-all | grep -wq apache2; then
	echo "Apache2 is installed"
	echo "Enabling existing virtual hosts"
	cd /etc/apache2/sites-available
	for site_config in *.conf; do
		a2ensite "$site_config"
	done
	cd ~
	service apache2 restart
else
	echo "Apache2 is not installed"
fi

# MySQL
if service --status-all | grep -wq mysql; then
	echo "MySQL is installed"
	echo "Enabling existing virtual hosts"
	service mysql restart
else
	echo "MySQL is not installed"
fi

# Add a user prompt loop to allow the user to decide when to exit
read -p "Press enter to quit the script: " input
