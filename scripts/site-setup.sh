#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
   exit 1
fi

DIVIDER="\n***************************************\n\n"

# Welcome and instructions
printf $DIVIDER
printf "Lyquix site setup script\n"
printf $DIVIDER

# Virtual Hosts
printf "VIRTUAL HOSTS\n"
printf "The script will setup the base virtual hosts configuration. Using the main domain name it will:\n"
printf " * Setup configuration files for example.com (with alias www.example.com), and dev.example.com\n"
printf " * Setup the necessary directories\n"
while true; do
	read -p "Please enter the LOCAL domain for the site (e.g. example.test): " localdomain
	case $localdomain in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Please enter the PRODUCTION domain for the site (e.g. example.com): " proddomain
	case $proddomain in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done

VIRTUALHOST="<VirtualHost *:80>\n\tServerName $localdomain\n\tDocumentRoot /srv/www/$proddomain/public_html/\n\tCustomLog /dev/null combined\n</VirtualHost>\n";
printf "$VIRTUALHOST" > /etc/apache2/sites-available/$localdomain.conf

# Create directories
mkdir -p /srv/www/$proddomain/public_html
chown -R www-data:www-data /srv/www/$proddomain

# Update permissions
chown -R www-data:www-data /srv/www/$proddomain
chmod -R g+w,o+w /srv/www/$proddomain

# Enable sites
a2ensite $localdomain
service apache2 reload

printf "You can now copy the site files to:\n\t/srv/www/$proddomain\nand you can reach the site at:\n\thttp://$localdomain/\n";


printf "Setup databases and users\n"

printf "\nPlease set name for databases, users and passwords\n"
while true; do
	read -p "Database name: " dbname
	case $dbname in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done

printf "Create database $dbname...\n"
mysql -u dbuser -pdbpassword -e "CREATE DATABASE $dbname;"

printf "You can now import the site database from a dump file using the command:\n\tmysql -u dbuser -pdbpassword $dbname < dumpfile.sql\n";

exit