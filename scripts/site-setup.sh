#!/bin/bash

CURRDIR="${PWD}"
cd /srv/www

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

echo "Database name..."
echo "For a new site:"
echo "  As convention, use the same name as the production domain without the TLD."
echo "  For example, if the production domain is example.com, the database name should be example"
echo "For an existing site:"
echo "  Make sure you are using the same database name specified in wp-secrets.php"
while true; do
	read -p "Enter the database name: " DBNAME
	case $DBNAME in
	"") printf "Database name may not be left blank\n" ;;
	*) break ;;
	esac
done

echo "Create database $DBNAME..."
mysql -u dbuser -pdbpassword -h 127.0.0.1 -e "CREATE DATABASE $DBNAME;"

# Prompt to install WordPress
read -p "Do you want to install WordPress? (y/n): " INSTALL_WP
if [ "$INSTALL_WP" != "${INSTALL_WP#[Yy]}" ]; then
	echo "Generating .gitignore file..."
	GITIGNORE="$(
		cat <<'EOF'
# Operating system files
[Tt]humbs.db
[Dd]esktop.ini
*.DS_store
.DS_store?
*Zone.Identifier

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

	echo "If this is a new site, please copy now the .htaccess file generated by the server"
	echo "to the root directory: /srv/www/$PRODDOMAIN/public_html"
	read -p "Press Enter when you are ready to continue..."
	chown www-data:www-data /srv/www/$PRODDOMAIN/public_html/.htaccess
	chmod 666 /srv/www/$PRODDOMAIN/public_html/.htaccess

	# Set default admin username
	WP_ADMIN_USER="admin_$(tr -dc a-z0-9 </dev/urandom | head -c 8)"

	# Generate random password
	WP_ADMIN_PASS=$(tr -dc '[:print:]' </dev/urandom | tr -d \'' `"' | head -c 24)

	# Prompt for WordPress admin email
	while true; do
		read -p "Please enter the WordPress admin email: " WP_ADMIN_EMAIL
		case $WP_ADMIN_EMAIL in
		"") echo "Admin email may not be left blank" ;;
		*) break ;;
		esac
	done

	# Prompt for Site Title
	while true; do
		read -p "Please enter the Site Title: " WP_TITLE
		case $WP_TITLE in
		"") echo "Site title may not be left blank" ;;
		*) break ;;
		esac
	done

	# Prompt for Tagline
	read -p "Please enter the Tagline: " WP_TAGLINE

	# Prompt for Blog page name
	read -p "Please enter the Blog page name e.g. Blog, News, Updates, etc. (Default: Blog): " BLOG_PAGE_NAME
	if [ -z "$BLOG_PAGE_NAME" ]; then
		BLOG_PAGE_NAME="Blog"
	fi

	# WordPress Installation and Configuration
	WP_DB_NAME=$DBNAME
	WP_DB_USER="dbuser"
	WP_DB_PASS="dbpassword"
	WP_DB_HOST="127.0.0.1"
	WP_DB_PREFIX="$(tr -dc a-z </dev/urandom | head -c 1)$(tr -dc a-z0-9 </dev/urandom | head -c 5)_"
	WP_URL="https://$LOCALDOMAIN"
	PLUGINS=(
		"aryo-activity-log"
		"post-smtp" "redirection"
		"wordpress-seo"
		"duplicate-post"
		"simple-custom-post-order"
		"tinymce-advanced"
		"html-editor-syntax-highlighter"
		"ewww-image-optimizer"
		"w3-total-cache"
		"wordfence"
		"zero-spam"
		# ACF Pro
		"https://github.com/pronamic/advanced-custom-fields-pro/archive/refs/heads/main.zip"
		# ACF Extended Pro Phone Number Addon
		"https://www.acf-extended.com/addons/acf-extended-pro-libphonenumber.zip"
	)

	# Check if WP-CLI is installed
	if ! command -v wp &>/dev/null; then
		echo "WP-CLI could not be found, installing it now..."
		curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
		chmod +x wp-cli.phar
		sudo mv wp-cli.phar /usr/local/bin/wp
	fi

	cd /srv/www/$PRODDOMAIN/public_html

	# Create wp-cli.yml with the apache_modules configuration
	sudo -u www-data cat >wp-cli.yml <<EOF
apache_modules:
  - mod_rewrite
EOF

	# Download and configure WordPress
	sudo -u www-data wp core download --path=/srv/www/$PRODDOMAIN/public_html --locale=en_US --allow-root

	# Create wp-config.php
	echo "Create wp-config.php..."
	sudo -u www-data wp config create --dbname=$WP_DB_NAME --dbuser=$WP_DB_USER --dbpass="$WP_DB_PASS" --dbhost=$WP_DB_HOST --dbprefix=$WP_DB_PREFIX --path=. --allow-root

	# Install WordPress
	sudo -u www-data wp core install --url=$WP_URL --title="$WP_TITLE" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL --allow-root

	# Set WordPress settings
	sudo -u www-data wp option update blogdescription "$WP_TAGLINE" --allow-root
	sudo -u www-data wp option update timezone_string "America/New_York" --allow-root
	sudo -u www-data wp option update date_format "F j, Y" --allow-root
	sudo -u www-data wp option update time_format "g:i a" --allow-root
	sudo -u www-data wp option update rss_use_excerpt 1 --allow-root
	sudo -u www-data wp option update blog_public 0 --allow-root

	# Install and configure plugins
	for plugin in "${PLUGINS[@]}"; do
		sudo -u www-data wp plugin install $plugin --activate --allow-root
	done

	# Get the latest commit hash for the specified branch
	THEME_DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/Lyquix/wp_theme_lyquix/releases/latest" | grep -oP '"zipball_url": "\K[^"]+' | head -1)

	# Download the ZIP file
	curl -L -o wp_theme_lyquix.zip $THEME_DOWNLOAD_URL

	# Extract the ZIP file to the target directory
	sudo -u www-data unzip -q wp_theme_lyquix.zip -d /srv/www/$PRODDOMAIN/public_html/wp-content/themes

	# Move the extracted folder to the target directory
	mv /srv/www/$PRODDOMAIN/public_html/wp-content/themes/*wp_theme_lyquix* /srv/www/$PRODDOMAIN/public_html/wp-content/themes/lyquix

	# Clean up the downloaded ZIP file
	rm wp_theme_lyquix.zip

	# Activate the theme
	sudo -u www-data wp theme activate lyquix --allow-root

	# Remove default themes
	sudo -u www-data wp theme delete twentytwentyfour --allow-root
	sudo -u www-data wp theme delete twentytwentythree --allow-root
	sudo -u www-data wp theme delete twentytwentytwo --allow-root

	# Clean up
	sudo -u www-data wp plugin delete hello --allow-root
	sudo -u www-data wp plugin delete akismet --allow-root

	# Create Home and Blog pages
	HOME_PAGE_ID=$(sudo -u www-data wp post create --post_type=page --post_title='Home' --post_status=publish --porcelain --allow-root)
	BLOG_PAGE_ID=$(sudo -u www-data wp post create --post_type=page --post_title="$BLOG_PAGE_NAME" --post_status=publish --porcelain --allow-root)
	BLOG_PAGE_SLUG=$(sudo -u www-data wp post get $BLOG_PAGE_ID --field=post_name --allow-root)

	# Set up permalinks and other settings to bypass the setup wizard
	sudo -u www-data wp rewrite structure "/$BLOG_PAGE_SLUG/%postname%/" --hard --allow-root
	sudo -u www-data wp rewrite flush --hard --allow-root
	sudo -u www-data wp option update show_on_front 'page' --allow-root
	sudo -u www-data wp option update page_on_front $HOME_PAGE_ID --allow-root
	sudo -u www-data wp option update page_for_posts $BLOG_PAGE_ID --allow-root
	sudo -u www-data wp option update blog_public 1 --allow-root

	# Update .htaccess
	sudo -u www-data wp rewrite flush --allow-root

	echo "For a new site, please copy now the files wp-config.php, wp-secrets.php, and deploy-config.php generated by the server"
	echo "to the root directory /srv/www/$PRODDOMAIN/public_html"
	read -p "Press Enter when you are ready to continue..."

	# Update permissions
	echo "Updating permissions..."
	chown -R www-data:www-data /srv/www/$PRODDOMAIN
	find /srv/www/$PRODDOMAIN/public_html -type f -exec chmod 666 {} \;
	find /srv/www/$PRODDOMAIN/public_html -type d -exec chmod 777 {} \;
	chmod +x /srv/www/$PRODDOMAIN/public_html/wp-content/themes/lyquix/postinstall.sh
	sudo -u www-data /srv/www/$PRODDOMAIN/public_html/wp-content/themes/lyquix/postinstall.sh

	# Update wp-config.php
	echo "Updating table prefix in wp-config.php..."
	FIND="\$table_prefix = 'wp_';"
	REPLACE="\$table_prefix = '$WP_DB_PREFIX'"
	perl -pi -e "s/\Q$FIND/\E$REPLACE/m" /srv/www/$PRODDOMAIN/public_html/wp-config.php

	# Update wp-secrets.php
	echo "Updating database name in wp-secrets.php..."
	FIND="'local' => 'dbname'"
	REPLACE="'local' => '$DBNAME';"
	perl -pi -e "s/$FIND/$REPLACE/m" /srv/www/$PRODDOMAIN/public_html/wp-secrets.php

	# Reset ACF Options for Gutenberg blocks
	echo "Resetting ACF Options for Gutenberg blocks..."
	ACF_RESET="$(
		cat <<'EOF'
<?php
// Load WordPress
require_once(dirname(__FILE__) . '/wp-load.php');

// Require the blocks functions file
require_once(get_stylesheet_directory() . '/php/blocks.php');

// Get the global field groups
$field_groups = \\lqx\\blocks\\get_global_field_groups();

// Reset the field groups
foreach ($field_groups as $field_group) {
	if (isset($field_group['sub_fields'])) {
		foreach ($field_group['sub_fields'] as $sub_field) {
			\\lqx\\blocks\\reset_field($sub_field, [$field_group['name']]);
		}
	}
}
?>
EOF
	)"
	echo -e "$ACF_RESET" >/srv/www/$PRODDOMAIN/public_html/acf-reset.php
	php /srv/www/$PRODDOMAIN/public_html/acf-reset.php
	rm /srv/www/$PRODDOMAIN/public_html/acf-reset.php

	echo "WordPress installation and configuration complete!"
fi

printf $DIVIDER
printf "SITE SETUP COMPLETE!!!\n\n"
echo "You can reach the site at:"
echo "    https://$LOCALDOMAIN/"
echo "The root directory is:"
echo "    /srv/www/$PRODDOMAIN/public_html"
echo "For an existing site:"
echo " - Clone the site repository to public_html directory under the root directory"
echo "    /srv/www/$PRODDOMAIN/public_html"
echo " - Import the site database from a dump file using the command:"
echo "    mysql -u dbuser -pdbpassword -h 127.0.0.1 $DBNAME < dumpfile.sql"

if [ "$INSTALL_WP" != "${INSTALL_WP#[Yy]}" ]; then
	echo "You can log into WordPress dashboard:"
	echo "    https://$LOCALDOMAIN/wp-admin"
	echo "    Username: $WP_ADMIN_USER"
	echo "    Password: $WP_ADMIN_PASS"
	echo "Open the theme in VSCode:"
	UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}' | cut -d'.' -f1)
	echo "    \\\\wsl.localhost\\Ubuntu\\home\\ubuntu\\Docker\\ubuntu$UBUNTU_VERSION\\www\\$PRODDOMAIN\\public_html\\wp-content\\themes\\lyquix"
	echo "Open the WSL terminal in VSCode and finish the theme installation"
	echo "    bun install"
	echo "    chmod +x ./postinstall.sh"
	echo "    ./postinstall.sh"
	echo "Start the automatic build process"
	echo "    bun run watch"
fi

printf $DIVIDER

cd $CURRDIR

exit
