#!/bin/bash

CURRDIR="${PWD}"
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

# Prompt to install WordPress
read -p "Do you want to install WordPress? (y/n): " INSTALL_WP
if [ "$INSTALL_WP" != "${INSTALL_WP#[Yy]}" ]; then

    # Set default admin username
    WP_ADMIN_USER="admin"

    # Generate random password
    WP_ADMIN_PASS=$(openssl rand -base64 16)
    echo "Generated WordPress admin password: $WP_ADMIN_PASS"

    # Prompt for WordPress admin email
    read -p "Please enter the WordPress admin email: " WP_ADMIN_EMAIL

    # Prompt for Site Title
    read -p "Please enter the Site Title: " WP_TITLE

    # Prompt for Tagline
    read -p "Please enter the Tagline: " WP_TAGLINE

    # Prompt for Blog page name
    read -p "Please enter the Blog page name (e.g. Blog, News, Updates, etc.): " BLOG_PAGE_NAME

    # WordPress Installation and Configuration
    WP_DB_NAME=$DBNAME
    WP_DB_USER="dbuser"
    WP_DB_PASS="dbpassword"
    WP_DB_HOST="127.0.0.1"
    WP_URL="https://$LOCALDOMAIN"
    THEME_REPO="git@bitbucket.org:lyquix/wp_theme_lyquix.git"
    THEME_DIR="lyquix"
    THEME_BRANCH="3.x-dev"
    PLUGINS=("aryo-activity-log" "post-smtp" "redirection" "wordpress-seo" "duplicate-post" "simple-custom-post-order" "tinymce-advanced" "html-editor-syntax-highlighter" "ewww-image-optimizer" "w3-total-cache" "wordfence") # Add the plugins you need

    # Check if WP-CLI is installed
    if ! command -v wp &> /dev/null
    then
        echo "WP-CLI could not be found, installing it now..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
    fi

    # Create wp-cli.yml with the apache_modules configuration
        cat > wp-cli.yml << EOF
apache_modules:
  - mod_rewrite
EOF

    # Download and configure WordPress
    wp core download --path=/srv/www/$PRODDOMAIN/public_html --locale=en_US --allow-root
    cd /srv/www/$PRODDOMAIN/public_html

    # Create wp-config.php
    echo "Create wp-config.php..."
    wp config create --dbname=$WP_DB_NAME --dbuser=$WP_DB_USER --dbpass=$WP_DB_PASS --dbhost=$WP_DB_HOST --path=. --allow-root

    # Install WordPress
    wp core install --url=$WP_URL --title="$WP_TITLE" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL --allow-root

    # Set WordPress settings
    wp option update blogdescription "$WP_TAGLINE" --allow-root
    wp option update timezone_string "America/New_York" --allow-root
    wp option update date_format "F j, Y" --allow-root
    wp option update time_format "g:i a" --allow-root
    wp option update rss_use_excerpt 1 --allow-root

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

    # Ensure OpenSSH is installed
    if ! command -v ssh &> /dev/null
    then
        echo "OpenSSH is not installed, installing it now..."
        sudo apt-get update
        sudo apt-get install -y openssh-client
    fi

    # Ensure SSH key is available and start SSH agent
    eval "$(ssh-agent -s)"
    sudo chmod 644 $CURRDIR/ssh/id_rsa
    ssh-add $CURRDIR/ssh/id_rsa

    # Clone the theme repository
    git clone --branch $THEME_BRANCH $THEME_REPO wp-content/themes/$THEME_DIR
    wp theme activate $THEME_DIR --allow-root

    # Revert ssh permissions
    sudo chmod 600 $CURRDIR/ssh/id_rsa

    # Remove default themes
    wp theme delete twentytwentyfour --allow-root
    wp theme delete twentytwentythree --allow-root
    wp theme delete twentytwentytwo --allow-root

    # Clean up
    wp plugin delete hello --allow-root
    wp plugin delete akismet --allow-root

    # Create Home and Blog pages
    HOME_PAGE_ID=$(wp post create --post_type=page --post_title='Home' --post_status=publish --porcelain --allow-root)
    BLOG_PAGE_ID=$(wp post create --post_type=page --post_title="$BLOG_PAGE_NAME" --post_status=publish --porcelain --allow-root)
    BLOG_PAGE_SLUG=$(wp post get $BLOG_PAGE_ID --field=post_name --allow-root)

    # Set up permalinks and other settings to bypass the setup wizard
    wp rewrite structure "/$BLOG_PAGE_SLUG/%postname%/" --hard --allow-root
    wp rewrite flush --hard --allow-root
    wp option update show_on_front 'page' --allow-root
    wp option update page_on_front $HOME_PAGE_ID --allow-root
    wp option update page_for_posts $BLOG_PAGE_ID --allow-root
    wp option update blog_public 1 --allow-root

    # Update .htaccess
    wp rewrite flush --allow-root

    sudo chmod +x wp-content/themes/$THEME_DIR/postinstall.sh && wp-content/themes/$THEME_DIR/postinstall.sh

    echo "WordPress installation and configuration complete!"
fi

exit
