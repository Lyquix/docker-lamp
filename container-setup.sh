#!/bin/bash

DIVIDER="\n***************************************\n\n"
CURRDIR="${PWD}"
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPTDIR}

# Welcome and instructions
printf $DIVIDER
printf "Lyquix Docker container setup script\n"
printf $DIVIDER

# Update scripts permissions
chmod +x scripts/*.sh

# Build containers
for COUNTER in 18 20 22
do
	printf "Ubuntu $COUNTER.04 container...\n"
	printf " - Linking directories\n"
	mkdir ubuntu$COUNTER/mysql
	mkdir ubuntu$COUNTER/sites-available
	mkdir ubuntu$COUNTER/www
	printf " - Copying scripts\n"
	cp scripts/site-setup.sh ubuntu$COUNTER/www
	cp scripts/file-permissions.sh ubuntu$COUNTER/www
	printf " - Stoping and removing existing container\n"
	docker stop ubuntu$COUNTER
	docker rm ubuntu$COUNTER
	printf " - Building new container\n"
	docker build . -t ubuntu$COUNTER -f ubuntu$COUNTER/Dockerfile
	printf " - Running container\n"
	docker run -p 80:80 -v $SCRIPTDIR/ubuntu$COUNTER/sites-available:/etc/apache2/sites-available -v $SCRIPTDIR/ubuntu$COUNTER/www:/srv/www/ -v $SCRIPTDIR/ubuntu$COUNTER/mysql:/var/lib/mysql/ -d -t --name ubuntu$COUNTER ubuntu$COUNTER
	printf " - Stopping container\n"
	docker stop ubuntu$COUNTER
	printf "Done!\n"
done

cd ${CURRDIR}

exit