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
	read -p "Please enter the LOCAL domain for the site (e.g. example.test): " LOCALDOMAIN
	case $LOCALDOMAIN in
	"") printf "Domain may not be left blank\n" ;;
	*) break ;;
	esac
done
while true; do
	read -p "Please enter the PRODUCTION domain for the site (e.g. example.com): " PRODDOMAIN
	case $PRODDOMAIN in
	"") printf "Domain may not be left blank\n" ;;
	*) break ;;
	esac
done

VIRTUALHOST="<VirtualHost *:80>
	ServerName $LOCALDOMAIN
	DocumentRoot /srv/www/$PRODDOMAIN/public_html/
	CustomLog /dev/null combined
	RewriteEngine On
	RewriteCond %{HTTPS} off
	RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>
<VirtualHost *:443>
	ServerName $LOCALDOMAIN
	DocumentRoot /srv/www/$PRODDOMAIN/public_html/
	CustomLog /dev/null combined
	SSLEngine on
	SSLOptions +StrictRequire
	SSLCertificateFile /etc/apache2/ssl/$LOCALDOMAIN.crt
	SSLCertificateKeyFile /etc/apache2/ssl/$LOCALDOMAIN.key
</VirtualHost>"
echo -e "$VIRTUALHOST" > /etc/apache2/sites-available/$LOCALDOMAIN.conf

printf "Creating SSL certificate...\n"
cp /etc/apache2/ssl/ssl.cnf /etc/apache2/ssl/$LOCALDOMAIN.cnf
sed -i "s/example\.test/$LOCALDOMAIN/g" /etc/apache2/ssl/$LOCALDOMAIN.cnf
openssl genrsa -out /etc/apache2/ssl/$LOCALDOMAIN.key 2048
openssl req -new -key /etc/apache2/ssl/$LOCALDOMAIN.key -out /etc/apache2/ssl/$LOCALDOMAIN.csr \
  -subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=Lyquix/CN=$LOCALDOMAIN"
openssl x509 -req -in /etc/apache2/ssl/$LOCALDOMAIN.csr -CA /etc/apache2/ssl/root.pem \
	-CAkey /etc/apache2/ssl/root.key -CAcreateserial -out /etc/apache2/ssl/$LOCALDOMAIN.crt \
	-days 3650 -sha256 -extfile /etc/apache2/ssl/$LOCALDOMAIN.cnf -extensions req_ext

# Create directories
printf "Creating directories...\n"
mkdir -p /srv/www/$PRODDOMAIN/public_html

# Update permissions
printf "Updating permissions...\n"
chown -R www-data:www-data /srv/www/$PRODDOMAIN
chmod -R g+w,o+w /srv/www/$PRODDOMAIN

# Enable sites
printf "Enabling sites...\n"
a2ensite $LOCALDOMAIN
service apache2 reload

printf "You can now copy the site files to:\n\t/srv/www/$PRODDOMAIN\nand you can reach the site at:\n\thttp://$LOCALDOMAIN/\n"

while true; do
	read -p "Database name: " DBNAME
	case $DBNAME in
	"") printf "Database name may not be left blank\n" ;;
	*) break ;;
	esac
done

printf "Create database $DBNAME...\n"
mysql -u dbuser -pdbpassword -h 127.0.0.1 -e "CREATE DATABASE $DBNAME;"

printf "You can now import the site database from a dump file using the command:\n\tmysql -u dbuser -pdbpassword -h 127.0.0.1 $DBNAME < dumpfile.sql\n"

exit
