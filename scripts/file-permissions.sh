#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
	 exec sudo "$0" "$@"
   exit 1
fi

DIVIDER="\n***************************************\n\n"
CURRDIR="${PWD}"

# Welcome and instructions
printf $DIVIDER
printf "Lyquix file permissions script\n"
printf $DIVIDER

# Prompt to continue
while true; do
	read -p "Fix file permissions for ALL sites [Y/N]? " fixall
	case $fixall in
		[Y]* ) break;;
		[N]* ) break;;
		* ) printf "Please answer Y or N\n";;
	esac
done

cd /srv/www/

if [[ "$fixall" == "Y" ]]; then
	printf "Updating file permissions for all sites, please wait...\n"
	chown -R www-data:www-data /srv/www/*
	chmod -R g+w,o+w /srv/www/*
	find /srv/www/*/public_html -type d -exec chmod g+ws,o+ws {} \;
	find /srv/www/*/public_html -name "*.sh" -type f -exec chmod +x {} \;
else
	printf "Please select folder:\n"
	select dir in */; do test -n "$dir" && break; echo ">>> Invalid Selection"; done
	printf "Updating file permissions for /srv/www/$dir...\n"
	chown -R www-data:www-data /srv/www/$dir
	chmod -R g+w,o+w /srv/www/$dir
	find /srv/www/$dir/public_html -type d -exec chmod g+ws,o+ws {} \;
	find /srv/www/$dir/public_html -name "*.sh" -type f -exec chmod +x {} \;
fi

cd $CURRDIR
printf "Done\n"

exit
