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
printf "Ubuntu 18.04 container...\n"
mkdir ubuntu18/mysql
mkdir ubuntu18/sites-available
mkdir ubuntu18/www
docker build . -t ubuntu18 -f ubuntu18/Dockerfile
docker run -p 80:80 -v ${PWD}/sites-available:/etc/apache2/sites-available -v ${PWD}/www:/srv/www/ -v ${PWD}/mysql:/var/lib/mysql/ -d -t --name ubuntu18 ubuntu18
docker stop ubuntu18
printf "Done\n"

printf "Ubuntu 20.04 container...\n"
mkdir ubuntu20/mysql
mkdir ubuntu20/sites-available
mkdir ubuntu20/www
docker build . -t ubuntu20 -f ubuntu20/Dockerfile
docker run -p 80:80 -v ${PWD}/sites-available:/etc/apache2/sites-available -v ${PWD}/www:/srv/www/ -v ${PWD}/mysql:/var/lib/mysql/ -d -t --name ubuntu20 ubuntu20
docker stop ubuntu20
printf "Done\n"

cd ${CURRDIR}

exit