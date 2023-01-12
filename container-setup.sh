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
for COUNTER in 18 20
do
	printf "Ubuntu $COUNTER.04 container...\n"
	mkdir ubuntu$COUNTER/mysql
	mkdir ubuntu$COUNTER/sites-available
	mkdir ubuntu$COUNTER/www
	cp scripts/site-setup.sh ubuntu$COUNTER/www
	cp scripts/file-permissions.sh ubuntu$COUNTER/www
	docker build . -t ubuntu$COUNTER -f ubuntu$COUNTER/Dockerfile
	docker run -p 80:80 -v ${PWD}/ubuntu$COUNTER/sites-available:/etc/apache2/sites-available -v ${PWD}/ubuntu$COUNTER/www:/srv/www/ -v ${PWD}/ubuntu$COUNTER/mysql:/var/lib/mysql/ -d -t --name ubuntu$COUNTER ubuntu$COUNTER
	docker stop ubuntu$COUNTER
	printf "Done\n"
done

cd ${CURRDIR}

exit