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
CURRDIR="${PWD}"
cd "$(dirname "${BASH_SOURCE[0]}")"

# Welcome and instructions
printf $DIVIDER
printf "Lyquix file permissions script\n"
printf $DIVIDER

# Prompt whether to do all sites or a specific one
while true; do
	read -p "Fix ALL sites? [Y/N] " FIXALL
	case $FIXALL in
	[YyNn]*) break ;;
	*) printf "Please answer Y or N\n" ;;
	esac
done

# Prompt whether to do the whole site or just the theme/template folder
while true; do
	read -p "Fix ONLY the WordPress themes files? [Y/N] " FIXTHEME
	case $FIXTHEME in
	[YyNn]*) break ;;
	*) printf "Please answer Y or N\n" ;;
	esac
done

if [[ $FIXALL =~ ^[Yy]$ ]]; then
	WP="$(find /srv/www/*/public_html/wp-content/themes/* -maxdepth 0 -type d 2>/dev/null | wc -l)"

	if [[ $FIXTHEME =~ ^[Nn]$ ]]; then
		printf "Updating ALL sites\n"
		printf "Set www-data as owner\n"
		chown -R www-data:www-data /srv/www/*

		printf "Set permissions of files to 666\n"
		find /srv/www/*/public_html -type f -exec chmod 666 {} \;

		printf "Set permissions of directories to 777\n"
		find /srv/www/*/public_html -type d -exec chmod 777 {} \;
	else
		if [ "$WP" != "0" ]; then
			printf "Updating ALL sites, ONLY theme/template files\n"
			printf "Set www-data as owner\n"
			chown -R www-data:www-data /srv/www/*/public_html/wp-content/themes/*

			printf "Set permissions of files to 666\n"
			find /srv/www/*/public_html/wp-content/themes/* -type f -exec chmod 666 {} \;

			printf "Set permissions of directories to 777\n"
			find /srv/www/*/public_html/wp-content/themes/* -type d -exec chmod 777 {} \;
		else
			printf "WARNING: No WordPress themes found in /srv/www/*/public_html/wp-content/themes/\n"
		fi
	fi
	if [ "$WP" != "0" ]; then
		printf "Set execution permissions to node_modules/.bin\n"
		chmod +x /srv/www/*/public_html/wp-content/themes/*/node_modules/.bin/*
		
		printf "Set execution permissions to shell scripts\n"
		find /srv/www/*/public_html/wp-content/themes/* -name "*.sh" -type f -exec chmod +x {} \;
	fi
else
	printf "Please select folder:\n"
	select DIR in */; do
		test -n "$DIR" && break
		echo ">>> Invalid Selection"
	done

	WP="$(find /srv/www/$DIR/public_html/wp-content/themes/* -maxdepth 0 -type d 2>/dev/null | wc -l)"

	if [[ $FIXTHEME =~ ^[Nn]$ ]]; then
		printf "Updating /srv/www/$DIR\n"
		printf "Set www-data as owner\n"
		chown -R www-data:www-data /srv/www/$DIR

		printf "Set permissions of files to 666\n"
		find /srv/www/$DIR/public_html -type f -exec chmod 666 {} \;

		printf "Set permissions of directories to 777\n"
		find /srv/www/$DIR/public_html -type d -exec chmod 777 {} \;
	else
		if [ "$WP" != "0" ]; then
			printf "Updating /srv/www/$DIR, ONLY theme/template files\n"
			printf "Set www-data as owner\n"
			chown -R www-data:www-data /srv/www/$DIR/public_html/wp-content/themes/*

			printf "Set permissions of files to 666\n"
			find /srv/www/$DIR/public_html/wp-content/themes/* -type f -exec chmod 666 {} \;

			printf "Set permissions of directories to 777\n"
			find /srv/www/$DIR/public_html/wp-content/themes/* -type d -exec chmod 777 {} \;
		else
			printf "WARNING: No WordPress themes found in /srv/www/$DIR/public_html/wp-content/themes\n"
		fi
	fi
	if [ "$WP" != "0" ]; then
		printf "Set execution permissions to node_modules/.bin\n"
		chmod +x /srv/www/$DIR/public_html/wp-content/themes/*/node_modules/.bin/*
		
		printf "Set execution permissions to shell scripts\n"
		find /srv/www/$DIR/public_html/wp-content/themes/* -name "*.sh" -type f -exec chmod +x {} \;
	fi
fi

cd $CURRDIR
printf "Done\n"

exit
