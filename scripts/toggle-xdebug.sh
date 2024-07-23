#!/bin/bash

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# Function to check if Xdebug is installed
check_xdebug_installed() {
    if php -m | grep -q 'xdebug'; then
        echo "Xdebug is already installed."
        return 0
    else
        echo "Xdebug is not installed. Installing Xdebug..."
        sudo apt-get update
        sudo apt-get install -y php-xdebug
        return 1
    fi
}

toggle_xdebug() {
    check_xdebug_installed
    local INI_FILE="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"

    if [ "$1" == "enable" ]; then
        # Prompt the user for the WSL IP address
        read -p "Enter the WSL IP address (found via wsl hostname -I): " WSL_IP

        # Validate the IP address format
        if [[ ! $WSL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid IP address format."
            exit 1
        fi

        # Clear the xdebug.ini file
        sudo truncate -s 0 "$INI_FILE"

        # Add the Xdebug configuration
        echo "zend_extension=xdebug.so" | sudo tee "$INI_FILE"
        echo "xdebug.mode=develop,debug" | sudo tee -a "$INI_FILE"
        echo "xdebug.client_host=${WSL_IP}" | sudo tee -a "$INI_FILE"
        echo "xdebug.client_port=9003" | sudo tee -a "$INI_FILE"
        echo "xdebug.max_nesting_level=500" | sudo tee -a "$INI_FILE"
        echo "xdebug.start_with_request=yes" | sudo tee -a "$INI_FILE"
        echo "xdebug.discover_client_host=0" | sudo tee -a "$INI_FILE"
        echo "xdebug.idekey=vsc" | sudo tee -a "$INI_FILE"
        sudo phpenmod xdebug
        echo "Xdebug enabled with client host ${WSL_IP}"
    elif [ "$1" == "disable" ]; then
        sudo phpdismod xdebug
        echo "Xdebug disabled"
    else
        echo "Usage: $0 {enable|disable}"
        exit 1
    fi

    # Restart PHP-FPM and Apache
    sudo service php${PHP_VERSION}-fpm restart
    sudo service apache2 restart
}

toggle_xdebug "$@"
