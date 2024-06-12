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

# Regenerate existing virtual hosts
echo "Regenerating existing virtual hosts"
VIRTUALHOSTS=($(ls /etc/apache2/sites-available/*.conf | grep -vE '000-default.conf|default-ssl.conf'))
for SITECONFIG in "${VIRTUALHOSTS[@]}"; do
	# Get the domain name from the configuration file
	LOCALDOMAIN=$(awk '/ServerName/ {print $2; exit}' "$SITECONFIG")
	DOCROOT=$(awk '/DocumentRoot/ {print $2; exit}' "$SITECONFIG")

	# Regenerate the virtual host configuration
	VIRTUALHOST="<VirtualHost *:80>
	ServerName $LOCALDOMAIN
	DocumentRoot $DOCROOT
	CustomLog /dev/null combined
	RewriteEngine On
	RewriteCond %{HTTPS} off
	RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
	SetEnv WPCONFIG_ENVNAME local
</VirtualHost>
<VirtualHost *:443>
	ServerName $LOCALDOMAIN
	DocumentRoot $DOCROOT
	CustomLog /dev/null combined
	SSLEngine on
	SSLOptions +StrictRequire
	SSLCertificateFile /etc/apache2/ssl/$LOCALDOMAIN.crt
	SSLCertificateKeyFile /etc/apache2/ssl/$LOCALDOMAIN.key
	SetEnv WPCONFIG_ENVNAME local
</VirtualHost>"
	echo -e "$VIRTUALHOST" > "$SITECONFIG"

	# Regenerate the SSL certificate
	cp /etc/apache2/ssl/ssl.cnf /etc/apache2/ssl/$LOCALDOMAIN.cnf
	sed -i "s/example\.test/$LOCALDOMAIN/g" /etc/apache2/ssl/$LOCALDOMAIN.cnf
	openssl genrsa -out /etc/apache2/ssl/$LOCALDOMAIN.key 2048
	openssl req -new -key /etc/apache2/ssl/$LOCALDOMAIN.key -out /etc/apache2/ssl/$LOCALDOMAIN.csr \
		-subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=Lyquix/CN=$LOCALDOMAIN"
	openssl x509 -req -in /etc/apache2/ssl/$LOCALDOMAIN.csr -CA /etc/apache2/ssl/root.pem \
		-CAkey /etc/apache2/ssl/root.key -CAcreateserial -out /etc/apache2/ssl/$LOCALDOMAIN.crt \
		-days 3650 -sha256 -extfile /etc/apache2/ssl/$LOCALDOMAIN.cnf -extensions req_ext

	# Enable the virtual host
	a2ensite "$LOCALDOMAIN"
done

# Restart Apache
service apache2 restart