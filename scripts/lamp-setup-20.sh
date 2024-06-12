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

# Welcome and instructions
printf $DIVIDER
printf "Lyquix LAMP server setup on Ubuntu 20.04\n"
printf $DIVIDER

# Install and update software
printf $DIVIDER
printf "INSTALL AND UPDATE SOFTWARE\n"
printf "Now the script will update Ubuntu and install all the necessary software.\n"
printf " * You will be prompted to enter the password for the MySQL root user\n"

printf "Update package repositories...\n"
apt-get update --fix-missing
apt-get -y -qq --no-install-recommends install software-properties-common
printf "Install apt-fast...\n"
add-apt-repository -y ppa:apt-fast/stable
apt-get update --fix-missing
apt-get -y -qq --no-install-recommends install apt-fast

printf "Install sudo...\n"
apt-fast install -y -qq --no-install-recommends sudo
printf "Add www-data user to sudoers...\n"
echo "www-data    ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

printf "Setup time zone...\n"
apt-fast install -y --no-install-recommends tzdata
echo "America/New_York" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata

printf "Install software...\n"
PCKGS=("curl" "vim" "openssl" "git" "zip" "unzip" "libcurl3-openssl-dev" "psmisc" "build-essential" "zlib1g-dev" "libpcre3" "libpcre3-dev" "software-properties-common" "apache2" "libapache2-mod-php" "libapache2-mod-fcgid" "mcrypt" "imagemagick" "php7.4" "php7.4-common" "php7.4-gd" "php7.4-imap" "php7.4-mysql" "php7.4-mysqli" "php7.4-cli" "php7.4-cgi" "php7.4-fpm" "php7.4-zip" "php-pear" "php-imagick" "php7.4-curl" "php7.4-mbstring" "php7.4-bcmath" "php7.4-xml" "php7.4-soap" "php7.4-opcache" "php7.4-intl" "php-apcu" "php-mail" "php-mail-mime" "php-all-dev" "php7.4-dev" "libapache2-mod-php7.4" "composer" "mysql-server" "mysql-client")
apt-fast -y -qq --no-install-recommends install ${PCKGS[@]}

# APACHE configuration
printf $DIVIDER
printf "APACHE CONFIGURATION\n"

printf "Apache modules...\n"
a2dismod php7.4
a2enmod expires headers rewrite ssl suphp proxy_fcgi setenvif mpm_event http2 security2

printf "Apache configurations...\n"
a2enconf php7.4-fpm
a2disconf security apache2-conf

if [ ! -f /etc/apache2/apache2.conf.orig ]; then
	printf "Backing up original configuration file to /etc/apache2/apache2.conf.orig\n"
	cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.orig
fi

printf "Changing MaxKeepAliveRequests to 0...\n"
FIND="^\s*MaxKeepAliveRequests \s*\d*"
REPLACE="MaxKeepAliveRequests 0"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

printf "Changing Timeout to 60...\n"
FIND="^\s*Timeout \s*\d*"
REPLACE="Timeout 60"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

printf "Adding security settings and caching...\n"
FIND="#<\/Directory>"
REPLACE="$(
	cat <<'EOF'
#</Directory>

# Disable Trace HTTP request
TraceEnable off

# Disable SSL v2 & v3
SSLProtocol -all +TLSv1.2 +TLSv1.3

# Disable server signature
ServerSignature Off
ServerTokens Prod

# Browser Caching
ExpiresActive On
ExpiresDefault "access plus 30 days"
ExpiresByType text/html "access plus 15 minutes"
Header unset Last-Modified
Header unset ETag
FileETag None
EOF
)"
REPLACE=${REPLACE//\//\\\/}   # Escape the / characters
REPLACE=${REPLACE//$'\n'/\\n} # Escape the new line characters
REPLACE=${REPLACE//\$/\\$}    # Escape the $ characters
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

printf "Adding <Directory /srv/www/> configuration for /srv/www...\n"
FIND="#<\/Directory>"
REPLACE="$(
	cat <<'EOF'
#</Directory>

<Directory /srv/www/>
    Options +FollowSymLinks -Indexes -Includes
    AllowOverride all
    Require all granted
    Header set Access-Control-Allow-Origin "*"
    Header set Timing-Allow-Origin: "*"
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options sameorigin
    Header set X-XSS-Protection "1; mode=block"
    # Disable unused HTTP request methods
    <LimitExcept GET POST HEAD OPTIONS>
      deny from all
    </LimitExcept>
</Directory>
EOF
)"
REPLACE=${REPLACE//\//\\\/}   # Escape the / characters
REPLACE=${REPLACE//$'\n'/\\n} # Escape the new line characters
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

if [ ! -f /etc/apache2/mods-available/deflate.conf.orig ]; then
	printf "Backing up original compression configuration file to /etc/apache2/mods-available/deflate.conf.orig\n"
	cp /etc/apache2/mods-available/deflate.conf /etc/apache2/mods-available/deflate.conf.orig
fi

printf "Adding compression for SVG and fonts...\n"
FIND="<\/IfModule>"
REPLACE="\t# Add SVG images\n\t\tAddOutputFilterByType DEFLATE image\/svg+xml\n\t\t# Add font files\n\t\tAddOutputFilterByType DEFLATE application\/x-font-woff\n\t\tAddOutputFilterByType DEFLATE application\/x-font-woff2\n\t\tAddOutputFilterByType DEFLATE application\/vnd.ms-fontobject\n\t\tAddOutputFilterByType DEFLATE application\/x-font-ttf\n\t\tAddOutputFilterByType DEFLATE application\/x-font-otf\n\t<\/IfModule>"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/mods-available/deflate.conf

if [ ! -f /etc/apache2/mods-available/mime.conf.orig ]; then
	printf "Backing up original MIME configuration file to /etc/apache2/mods-available/mime.conf.orig\n"
	cp /etc/apache2/mods-available/mime.conf /etc/apache2/mods-available/mime.conf.orig
fi

printf "Adding MIME types for font files...\n"
FIND="<IfModule mod_mime\.c>"
REPLACE="<IfModule mod_mime\.c>\n\n\t# Add font files\n\tAddType application\/x-font-woff2 \.woff2\n\tAddType application\/x-font-otf \.otf\n\tAddType application\/x-font-ttf \.ttf\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mime.conf

if [ ! -f /etc/apache2/mods-available/dir.conf.orig ]; then
	printf "Backing up original directory listing configuration file to /etc/apache2/mods-available/dir.conf.orig\n"
	cp /etc/apache2/mods-available/dir.conf /etc/apache2/mods-available/dir.conf.orig
fi

printf "Making index.php the default file for directory listing...\n"
FIND="index\.php "
REPLACE=""
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/mods-available/dir.conf

FIND="DirectoryIndex"
REPLACE="DirectoryIndex index\.php"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/apache2/mods-available/dir.conf

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
		-days 3650 -sha256 -extfile /etc/apache2/ssl/$LOCALDOMAIN.cnf
	openssl x509 -req -in /etc/apache2/ssl/$LOCALDOMAIN.csr -CA /etc/apache2/ssl/root.pem \
		-CAkey /etc/apache2/ssl/root.key -CAcreateserial -out /etc/apache2/ssl/$LOCALDOMAIN.crt \
		-days 3650 -sha256 -extfile /etc/apache2/ssl/$LOCALDOMAIN.cnf -extensions req_ext

	# Enable the virtual host
	a2ensite "$LOCALDOMAIN"
done

# Restart Apache
service apache2 restart

# PHP
printf $DIVIDER
printf "PHP\n"
printf "The script will update PHP configuration\n"

if [ ! -f /etc/php/7.4/fpm/php.ini.orig ]; then
	printf "Backing up PHP.ini configuration file to /etc/php/7.4/fpm/php.ini.orig\n"
	cp /etc/php/7.4/fpm/php.ini /etc/php/7.4/fpm/php.ini.orig
fi

FIND="^\s*output_buffering\s*=\s*.*"
REPLACE="output_buffering = Off"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*max_execution_time\s*=\s*.*"
REPLACE="max_execution_time = 60"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*error_reporting\s*=\s*.*"
REPLACE="error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*log_errors_max_len\s*=\s*.*"
REPLACE="log_errors_max_len = 0"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*post_max_size\s*=\s*.*"
REPLACE="post_max_size = 100M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*upload_max_filesize\s*=\s*.*"
REPLACE="upload_max_filesize = 100M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*short_open_tag\s*=\s*.*"
REPLACE="short_open_tag = On"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*;\s*max_input_vars\s*=\s*.*" # this is commented in the original file
REPLACE="max_input_vars = 5000"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

FIND="^\s*;\s*memory_limit\s*=\s*.*" # this is commented in the original file
REPLACE="memory_limit = 1024M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/7.4/fpm/php.ini

# Restart Apache
printf "Restarting PHP-FPM and Apache...\n"
service php7.4-fpm start
service apache2 restart

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

# Restart MySQL
service mysql restart

# Create dbuser
mysql -u root -h 127.0.0.1 -e "CREATE USER 'dbuser'@localhost IDENTIFIED BY 'dbpassword'; GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@localhost;"
printf "You can connect to the database with\n\tuser: dbuser\n\tpassword: dbpassword\n"

# phpMyAdmin
cd /var/www/html/
curl -L https://files.phpmyadmin.net/phpMyAdmin/5.2.0/phpMyAdmin-5.2.0-english.zip --output pma.zip
unzip -q pma.zip
mv phpMyAdmin-5.2.0-english pma
rm pma.zip
cd pma
cp config.sample.inc.php config.inc.php
FIND="\['auth_type'\] = 'cookie';"
REPLACE="['auth_type'] = 'config';\n\\\$cfg['Servers'][\\\$i]['user'] = 'dbuser';\n\\\$cfg['Servers'][\\\$i]['password'] = 'dbpassword';\n"
perl -pi -e "s/$FIND/$REPLACE/m" config.inc.php
FIND="\['host'\] = 'localhost'"
REPLACE="['host'] = '127.0.0.1'"
perl -pi -e "s/$FIND/$REPLACE/m" config.inc.php
printf "You can access phpMyAdmin at\n\thttp://localhost/pma\n"

# Search-Replace DB
cd /var/www/html
curl -L https://github.com/interconnectit/Search-Replace-DB/archive/refs/tags/3.1.zip --output srdb.zip
unzip -q srdb.zip
mv Search-Replace-DB-3.1 srdb
rm srdb.zip
cd srdb
sed -i '196s/()/("", "dbuser", "dbpassword", "127.0.0.1", "3306", "", "")/' index.php
printf "You can access Search-Replace-DB at\n\thttp://localhost/srdb\n"

# Initial file permissions
chown -R www-data:www-data /srv/www
chmod -R g+w,o+w /srv/www

exit
