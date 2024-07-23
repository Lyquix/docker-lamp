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
	
	echo "Copying the root certificate to WSL Trust Store"
	sudo cp ${SCRIPTDIR}/ssl/root.pem /usr/local/share/ca-certificates/lyquix.crt
	sudo update-ca-certificates
fi
cd ..

# Use whiptail to create a checkbox list
CHOICES=$(whiptail --separate-output --title "Select the Docker LAMP instances to create" --checklist "Select VERSIONS:" 10 60 4 \
	"18" "Ubuntu 18.04" on \
	"20" "Ubuntu 20.04" on \
	"22" "Ubuntu 22.04" on \
	"24" "Ubuntu 24.04" on \
	3>&1 1>&2 2>&3)

# Define the list of VERSIONS
VERSIONS=()

# Check if the user selected any VERSIONS
if [ -n "$CHOICES" ]; then
	# Process the selected VERSIONS
	for VERSION in $CHOICES; do
		VERSIONS+=("$VERSION")
	done
fi

for VERSION in "${VERSIONS[@]}"; do
	printf $DIVIDER
	echo "Ubuntu $VERSION.04 instance..."
	echo " - Linking directories"
	mkdir ubuntu$VERSION/mysql
	mkdir ubuntu$VERSION/sites-available
	mkdir ubuntu$VERSION/www
	mkdir ubuntu$VERSION/ssl

	echo " - Copying scripts"
	cp scripts/site-setup.sh ubuntu$VERSION/www
	cp scripts/file-permissions.sh ubuntu$VERSION/www
	cp scripts/regen-vhosts.sh ubuntu$VERSION/www
	cp scripts/toggle-xdebug.sh ubuntu$VERSION/www

	echo " - Copying SSL files"
	cp ssl/* ubuntu$VERSION/ssl

	printf " - Stoping and removing existing instance\n"
	docker stop ubuntu$VERSION
	docker rm ubuntu$VERSION

	# Check if the image already exists
	COMMITHASH=$(git log -n 1 --pretty=format:"%h" --follow scripts/lamp-setup-$VERSION.sh)
	if [ -z "$COMMITHASH" ]; then
		IMAGENAME="ubuntu$VERSION"
	else
		IMAGENAME="ubuntu$VERSION:$COMMITHASH"
	fi

	if docker inspect --format='{{.Id}}' "$IMAGENAME" 2>/dev/null; then
		echo " - Image $IMAGENAME already exists"

		# Prompt user if they want to rebuild the image
		read -p "Rebuild the image? [Y/N] " REBUILD
		case $REBUILD in
			[Yy]) docker build . -t "$IMAGENAME" -f ubuntu$VERSION/Dockerfile --pull --no-cache ;;
			*) break ;;
		esac

	else
		echo " - Building image $IMAGENAME..."
		docker build . -t "$IMAGENAME" -f ubuntu$VERSION/Dockerfile --pull --no-cache
	fi

	# Create the Docker container instance
	echo " - Creating instance..."
	docker create -p 80:80 -p 443:443 -v $SCRIPTDIR/ubuntu$VERSION/sites-available:/etc/apache2/sites-available/ -v $SCRIPTDIR/ubuntu$VERSION/www:/srv/www/ -v $SCRIPTDIR/ubuntu$VERSION/mysql:/var/lib/mysql/ -t --name ubuntu$VERSION $IMAGENAME

	echo " - Done!"
done

cd ${CURRDIR}

exit
