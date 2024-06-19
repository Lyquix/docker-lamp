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
printf "Lyquix LAMP server setup on Ubuntu 22.04\n"
printf $DIVIDER

# Install and update software
printf $DIVIDER
printf "INSTALL AND UPDATE SOFTWARE\n"
printf "Now the script will update Ubuntu and install all the necessary software.\n"
printf " * You will be prompted to enter the password for the MySQL root user\n"

printf "Update package repositories...\n"
apt-get -y -q update --fix-missing
apt-get -y -q --no-install-recommends install software-properties-common sudo curl wget
printf "Install apt-fast...\n"
/bin/bash -c "$(curl -sL https://git.io/vokNn)"

printf "Add www-data user to sudoers...\n"
echo "www-data    ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

printf "Setup time zone...\n"
apt-fast -y -q -no-install-recommends install tzdata
echo "America/New_York" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata

printf "Install software...\n"
PCKGS=("curl" "vim" "openssl" "git" "zip" "unzip" "libcurl3-openssl-dev" "psmisc" "build-essential" "zlib1g-dev" "libpcre3" "libpcre3-dev" "software-properties-common" "apache2" "libapache2-mod-php" "libapache2-mod-fcgid" "mcrypt" "imagemagick" "php8.1" "php8.1-common" "php8.1-gd" "php8.1-imap" "php8.1-mysql" "php8.1-mysqli" "php8.1-cli" "php8.1-cgi" "php8.1-fpm" "php8.1-zip" "php-pear" "php-imagick" "php8.1-curl" "php8.1-mbstring" "php8.1-bcmath" "php8.1-xml" "php8.1-soap" "php8.1-opcache" "php8.1-intl" "php-apcu" "php-mail" "php-mail-mime" "php-all-dev" "php8.1-dev" "libapache2-mod-php8.1" "composer")
apt-fast -y -q --no-install-recommends install ${PCKGS[@]}

# APACHE configuration
printf $DIVIDER
printf "APACHE CONFIGURATION\n"

printf "Apache modules...\n"
a2dismod php8.1 mpm_prefork
a2enmod expires headers rewrite ssl suphp proxy_fcgi setenvif mpm_event http2 security2

printf "Apache configurations...\n"
a2enconf php8.1-fpm
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

# Restart Apache
service apache2 restart

# PHP
printf $DIVIDER
printf "PHP\n"
printf "The script will update PHP configuration\n"

if [ ! -f /etc/php/8.1/fpm/php.ini.orig ]; then
	printf "Backing up PHP.ini configuration file to /etc/php/8.1/fpm/php.ini.orig\n"
	cp /etc/php/8.1/fpm/php.ini /etc/php/8.1/fpm/php.ini.orig
fi

FIND="^\s*output_buffering\s*=\s*.*"
REPLACE="output_buffering = Off"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*max_execution_time\s*=\s*.*"
REPLACE="max_execution_time = 60"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*error_reporting\s*=\s*.*"
REPLACE="error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*log_errors_max_len\s*=\s*.*"
REPLACE="log_errors_max_len = 0"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*post_max_size\s*=\s*.*"
REPLACE="post_max_size = 100M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*upload_max_filesize\s*=\s*.*"
REPLACE="upload_max_filesize = 100M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*short_open_tag\s*=\s*.*"
REPLACE="short_open_tag = On"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*;\s*max_input_vars\s*=\s*.*" # this is commented in the original file
REPLACE="max_input_vars = 5000"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

FIND="^\s*;\s*memory_limit\s*=\s*.*" # this is commented in the original file
REPLACE="memory_limit = 1024M"
printf "php.ini: $REPLACE\n"
perl -pi -e "s/$FIND/$REPLACE/m" /etc/php/8.1/fpm/php.ini

# Restart Apache
printf "Restarting PHP-FPM and Apache...\n"
service php8.1-fpm start
service apache2 restart

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
chown -R www-data:www-data /var/www

exit
