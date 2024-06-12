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

# Prompt to install WordPress
read -p "Do you want to install WordPress? (y/n): " INSTALL_WP
if [ "$INSTALL_WP" != "${INSTALL_WP#[Yy]}" ]; then
    # Prompt for WordPress admin details
    read -p "Please enter the WordPress admin username: " WP_ADMIN_USER
    while true; do
        read -sp "Please enter the WordPress admin password: " WP_ADMIN_PASS
        echo
        read -sp "Please confirm the WordPress admin password: " WP_ADMIN_PASS_CONFIRM
        echo
        [ "$WP_ADMIN_PASS" = "$WP_ADMIN_PASS_CONFIRM" ] && break
        echo "Passwords do not match. Please try again."
    done
    read -p "Please enter the WordPress admin email: " WP_ADMIN_EMAIL

    # WordPress Installation and Configuration
    WP_DB_NAME=$DBNAME
    WP_DB_USER="dbuser"
    WP_DB_PASS="dbpassword"
    WP_DB_HOST="127.0.0.1"
    WP_URL="https://$LOCALDOMAIN"
    WP_TITLE="Your Site Title"
    THEME_REPO="git@bitbucket.org:lyquix/wp_theme_lyquix.git"
    THEME_DIR="lyquix"
    PLUGINS=("aryo-activity-log" "post-smtp" "redirection" "wordpress-seo" "duplicate-post" "simple-custom-post-order" "tinymce-advanced" "html-editor-syntax-highlighter" "ewww-image-optimizer" "w3-total-cache" "wordfence") # Add the plugins you need

    # Check if WP-CLI is installed
    if ! command -v wp &> /dev/null
    then
        echo "WP-CLI could not be found, installing it now..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
    fi

    # Download and configure WordPress
    wp core download --path=/srv/www/$PRODDOMAIN/public_html --locale=en_US --allow-root
    cd /srv/www/$PRODDOMAIN/public_html

    # Create wp-config.php
    echo "Create wp-config.php..."
    wp config create --dbname=$WP_DB_NAME --dbuser=$WP_DB_USER --dbpass=$WP_DB_PASS --dbhost=$WP_DB_HOST --path=. --allow-root

    # Install WordPress
    wp core install --url=$WP_URL --title="$WP_TITLE" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL --allow-root

    # Set WordPress settings
    wp option update blogdescription "Just another WordPress site" --allow-root
    wp option update timezone_string "America/New_York" --allow-root
    wp option update date_format "F j, Y" --allow-root
    wp option update time_format "g:i a" --allow-root
    wp option update permalink_structure "/%postname%/" --allow-root

    # Install and configure plugins
    for plugin in "${PLUGINS[@]}"
    do
        wp plugin install $plugin --activate --allow-root
    done

    # Download and configure theme from repo
    if ! command -v git &> /dev/null
    then
        echo "Git is not installed. Please install Git and run the script again."
        exit 1
    fi

#    git clone $THEME_REPO wp-content/themes/$THEME_DIR
#    wp theme activate $THEME_DIR --allow-root

    # Clean up
    wp plugin delete hello --allow-root
    wp plugin delete akismet --allow-root

    # Set up permalinks and other settings to bypass the setup wizard
    wp rewrite structure '/%postname%/' --hard --allow-root
    wp rewrite flush --hard --allow-root
    wp option update show_on_front 'page' --allow-root
    wp option update page_on_front 2 --allow-root
    wp option update page_for_posts 2 --allow-root
    wp option update blog_public 1 --allow-root

    echo "WordPress installation and configuration complete!"
fi

exit
