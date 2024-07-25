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

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;")

# Function to check if Xdebug is installed
check_xdebug_installed() {
    if php -m | grep -q 'xdebug'; then
        echo "Xdebug is already installed."
        return 0
    else
        echo "Xdebug is not installed. Installing Xdebug..."
        apt-get update
        apt-get install -y php-xdebug
        
        # Prompt the user for the WSL IP address
        echo "Please obtain the IP address of WSL by running the following command on the Windows Command prompt:"
        echo " wsl hostname -I"

        while true; do
            read -p "Enter the WSL IP address: " WSL_IP

            # Validate the IP address format
            if [[ $WSL_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                # Further validate each octet
                valid=true
                IFS='.' read -ra ADDR <<< "$WSL_IP"
                for i in "${ADDR[@]}"; do
                    if [ $i -lt 0 ] || [ $i -gt 255 ]; then
                        valid=false
                        break
                    fi
                done

                if $valid; then
                    break
                fi
            fi

            echo "Invalid IP address"
        done

        # Clear the xdebug.ini file
        local INI_FILE="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"
        truncate -s 0 "$INI_FILE"

        XDEBUG_INI="$(
            cat <<'EOF'
zend_extension=xdebug.so
xdebug.mode=develop,debug
xdebug.client_host=WSL_IP
xdebug.client_port=9003
xdebug.max_nesting_level=500
xdebug.start_with_request=yes
xdebug.discover_client_host=0
xdebug.idekey=vsc
EOF
        )"
        XDEBUG_INI=${XDEBUG_INI//WSL_IP/$WSL_IP}

        phpenmod xdebug
        echo "Xdebug enabled with client host ${WSL_IP}"

        return 1
    fi
}

toggle_xdebug() {
    check_xdebug_installed

    if [ "$1" == "enable" ]; then
        phpenmod xdebug
        echo "Xdebug enabled"
    elif [ "$1" == "disable" ]; then
        phpdismod xdebug
        echo "Xdebug disabled"
    else
        echo "Usage: $0 {enable|disable}"
        exit 1
    fi

    # Restart PHP-FPM and Apache
    service php${PHP_VERSION}-fpm restart
    service apache2 restart
}

toggle_xdebug "$@"
