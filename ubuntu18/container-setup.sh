#!/bin/bash

DIVIDER="\n***************************************\n\n"

# Welcome and instructions
printf $DIVIDER
printf "Lyquix Docker container setup script\n"
printf $DIVIDER

# Build image
printf "Building from image...\n"
docker build -t ubuntu18 .

# Change permissions
chmod +x ./www/*.sh

# Run container from built image
printf "Run new container from built image...\n"
docker run -p 80:80 -p 22:22 -v ${PWD}/sites-available:/etc/apache2/sites-available -v ${PWD}/www:/srv/www/ -v ${PWD}/mysql:/var/lib/mysql/ -d -t --name ubuntu18 ubuntu18
printf "Done\n"
