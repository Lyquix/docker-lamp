#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
   exec sudo "$0" "$@"
   exit 1
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
   service apache2 start
else
   echo "Apache2 is not installed"
fi

# MySQL
if service --status-all | grep -wq mysql; then
   echo "MySQL is installed"
   echo "Enabling existing virtual hosts"
   service mysql start
else
   echo "MySQL is not installed"
fi

# Add a user prompt loop to allow the user to decide when to exit
read -p "Press enter to quit the script: " input
