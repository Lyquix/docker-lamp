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

# Welcome and instructions
printf $DIVIDER
printf "Lyquix file permissions script\n"
printf $DIVIDER

# Prompt to continue
while true; do
	read -p "Fix file permissions for ALL sites [Y/N]? " FIXALL
	case $FIXALL in
	[Y]*) break ;;
	[N]*) break ;;
	*) printf "Please answer Y or N\n" ;;
	esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ "$FIXALL" == "Y" ]]; then
	printf "Updating file permissions for all sites, please wait...\n"
	chown -R www-data:www-data /srv/www/*
	chmod -R g+w,o+w /srv/www/*
	find /srv/www/*/public_html -type d -exec chmod g+ws,o+ws {} \;
	find /srv/www/*/public_html -name "*.sh" -type f -exec chmod +x {} \;
else
	printf "Please select folder:\n"
	select DIR in */; do
		test -n "$DIR" && break
		echo ">>> Invalid Selection"
	done
	printf "Updating file permissions for /srv/www/$DIR...\n"
	chown -R www-data:www-data /srv/www/$DIR
	chmod -R g+w,o+w /srv/www/$DIR
	find /srv/www/$DIR/public_html -type d -exec chmod g+ws,o+ws {} \;
	find /srv/www/$DIR/public_html -name "*.sh" -type f -exec chmod +x {} \;
fi

cd $CURRDIR
printf "Done\n"

exit
