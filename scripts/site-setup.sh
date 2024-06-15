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
	echo "This script must be run as root!"
	if [ $NO_SUDO -eq 0 ]; then
		exec sudo /bin/bash "$0" "$@" --no-sudo
	fi
	exit
fi

# Check if the script is being run in Docker
if ! grep -q docker /proc/1/cgroup; then
	echo "This script must be run in the Docker terminal"
	exit
fi

DIVIDER="\n***************************************\n\n"

# Welcome and instructions
printf $DIVIDER
echo "Lyquix site setup script"
printf $DIVIDER

# Virtual Hosts
echo "VIRTUAL HOSTS"
echo "The script will setup the base virtual hosts configuration. Using the main domain name it will:"
echo " * Setup configuration files for example.com (with alias www.example.com), and dev.example.com"
echo " * Setup the necessary directories"
while true; do
	read -p "Please enter the LOCAL domain for the site (e.g. example.test): " LOCALDOMAIN
	case $LOCALDOMAIN in
	"") echo "Domain may not be left blank" ;;
	*) break ;;
	esac
done
while true; do
	read -p "Please enter the PRODUCTION domain for the site (e.g. example.com, without www): " PRODDOMAIN
	case $PRODDOMAIN in
	"") echo "Domain may not be left blank" ;;
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
	SetEnv WPCONFIG_ENVNAME local
</VirtualHost>
<VirtualHost *:443>
	ServerName $LOCALDOMAIN
	DocumentRoot /srv/www/$PRODDOMAIN/public_html/
	CustomLog /dev/null combined
	SSLEngine on
	SSLOptions +StrictRequire
	SSLCertificateFile /etc/apache2/ssl/$LOCALDOMAIN.crt
	SSLCertificateKeyFile /etc/apache2/ssl/$LOCALDOMAIN.key
	SetEnv WPCONFIG_ENVNAME local
</VirtualHost>"
echo -e "$VIRTUALHOST" >/etc/apache2/sites-available/$LOCALDOMAIN.conf

echo "Creating SSL certificate..."
cp /etc/apache2/ssl/ssl.cnf /etc/apache2/ssl/$LOCALDOMAIN.cnf
sed -i "s/example\.test/$LOCALDOMAIN/g" /etc/apache2/ssl/$LOCALDOMAIN.cnf
openssl genrsa -out /etc/apache2/ssl/$LOCALDOMAIN.key 2048
openssl req -new -key /etc/apache2/ssl/$LOCALDOMAIN.key -out /etc/apache2/ssl/$LOCALDOMAIN.csr \
	-subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=Lyquix/CN=$LOCALDOMAIN"
openssl x509 -req -in /etc/apache2/ssl/$LOCALDOMAIN.csr -CA /etc/apache2/ssl/root.pem \
	-CAkey /etc/apache2/ssl/root.key -CAcreateserial -out /etc/apache2/ssl/$LOCALDOMAIN.crt \
	-days 3650 -sha256 -extfile /etc/apache2/ssl/$LOCALDOMAIN.cnf -extensions req_ext

# Create directories
echo "Creating directories..."
mkdir -p /srv/www/$PRODDOMAIN/public_html

# Update permissions
echo "Updating permissions..."
chown -R www-data:www-data /srv/www/$PRODDOMAIN
chmod -R g+w,o+w /srv/www/$PRODDOMAIN

# Enable sites
echo "Enabling site..."
a2ensite $LOCALDOMAIN
service apache2 reload

echo "You can now copy the site files to:"
echo "    /srv/www/$PRODDOMAIN"
echo "and you can reach the site at:"
echo "    https://$LOCALDOMAIN/"

while true; do
	read -p "Database name: " DBNAME
	case $DBNAME in
	"") printf "Database name may not be left blank\n" ;;
	*) break ;;
	esac
done

echo "Create database $DBNAME..."
mysql -u dbuser -pdbpassword -h 127.0.0.1 -e "CREATE DATABASE $DBNAME;"

echo "You can now import the site database from a dump file using the command:"
echo "    mysql -u dbuser -pdbpassword -h 127.0.0.1 $DBNAME < dumpfile.sql"

echo "Generating .gitignore file..."

GITIGNORE="$(
	cat <<'EOF'
# Operating system files
[Tt]humbs.db
[Dd]esktop.ini
*.DS_store
.DS_store?

# Common files and directories
.env
.npmignore
.project
.revision
.settings
/__pma__/
/__srdb__/
/_pma_/
/_srdb_/
node_modules/
/phpmyadmin/
/phpMyAdmin*
/Search-Replace-DB-master/
/sitemap.xml
/sitemap.xml.gz
vendor/

# Log files
*.log

# WordPress core
/wp-content/upgrade/
/wp-content/uploads/

# WordPress sample themes
/wp-content/themes/twenty*/

# WordPress plugins
/wp-content/advanced-cache.php
/wp-content/ai1wm-backups/
/wp-content/backup-db/
/wp-content/backups/
/wp-content/backupswordpress-*/
/wp-content/blogs.dir/
/wp-content/cache/
/wp-content/debug.log
/wp-content/gallery/
/wp-content/object-cache.php
/wp-content/plugins/hello.php

# Activity Log
/wp-content/plugins/aryo-activity-log/logs/

# Gravity Forms
/wp-content/plugins/gravityforms/pdf-templates/
/wp-content/plugins/gravityforms/locale/
/wp-content/plugins/gravityforms/upload/

# Post SMTP
/wp-content/uploads/post-smtp/

# Redirection
/wp-content/uploads/redirection/

# EWWW Image Optimizer
/wp-content/ewww/

# W3 Total Cache
/wp-content/cache/config/
/wp-content/cache/log/
/wp-content/cache/tmp/
/wp-content/w3tc/
/wp-content/w3tc-config/


# Wordfence
/wp-content/plugins/wordfence/tmp/
/wp-content/wfcache/
/wp-content/wflogs/
/wp-content/wp-cache-config.php

# Add project-specific ignores here

EOF
)"
echo -e "$GITIGNORE" >/srv/www/$PRODDOMAIN/public_html/.gitignore

exit
