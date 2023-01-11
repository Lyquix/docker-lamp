#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
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
	chown -R www-data:www-data *
	chmod -R g+w,o+w *
	find */public_html -type d -exec chmod g+ws,o+ws {} \;
else
	printf "Please select folder:\n"
	select dir in */; do test -n "$dir" && break; echo ">>> Invalid Selection"; done
	printf "Updating file permissions for /srv/www/$dir...\n"
	chown -R www-data:www-data $dir
	chmod -R g+w,o+w $dir
	find $dir/public_html -type d -exec chmod g+ws,o+ws {} \;
fi

cd $CURRDIR
printf "Done\n"

exit
