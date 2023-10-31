#!/bin/bash

DIVIDER="\n***************************************\n\n"
CURRDIR="${PWD}"
SCRIPTDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd ${SCRIPTDIR}

# Welcome and instructions
printf $DIVIDER
printf "Lyquix Docker container setup script\n"
printf $DIVIDER

# Update scripts permissions
chmod +x scripts/*.sh

# Set up root CA
cd ssl
if [ ! -f "root.key" ] || [ ! -f "root.pem" ]; then
	printf $DIVIDER
	echo "Generate root CA private key"
	openssl genrsa -out root.key 2048

	printf $DIVIDER
	echo "Generate root certificate valid for 10 years"
	openssl req -x509 -new -nodes -key root.key -sha256 -days 3650 -out root.pem \
	  -subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=Lyquix/CN=lyquix.com"
fi
cd ..

# Build containers
for VERSION in 18 20 22; do
	printf $DIVIDER
	printf "Ubuntu $VERSION.04 container...\n"
	printf " - Linking directories\n"
	mkdir ubuntu$VERSION/mysql
	mkdir ubuntu$VERSION/sites-available
	mkdir ubuntu$VERSION/www
	mkdir ubuntu$VERSION/ssl
	printf " - Copying scripts\n"
	cp scripts/site-setup.sh ubuntu$VERSION/www
	cp scripts/file-permissions.sh ubuntu$VERSION/www
	printf " - Copying SSL files\n"
	cp ssl/* ubuntu$VERSION/ssl
	printf " - Stoping and removing existing container\n"
	docker stop ubuntu$VERSION
	docker rm ubuntu$VERSION
	printf " - Building new container\n"
	docker build . -t ubuntu$VERSION -f ubuntu$VERSION/Dockerfile
	printf " - Running container\n"
	docker run -p 80:80 -p 443:443 -v $SCRIPTDIR/ubuntu$VERSION/sites-available:/etc/apache2/sites-available -v $SCRIPTDIR/ubuntu$VERSION/www:/srv/www/ -v $SCRIPTDIR/ubuntu$VERSION/mysql:/var/lib/mysql/ -d -t --name ubuntu$VERSION ubuntu$VERSION
	printf " - Stopping container\n"
	docker stop ubuntu$VERSION
	printf "Done!\n"
done

cd ${CURRDIR}

exit
