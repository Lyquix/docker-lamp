#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
   exit 1
fi

# Function to check if a service is installed
is_service_installed() {
   service_name=$1
   if service --status-all | grep -wq "$service_name"; then
      echo "$service_name is installed"
      return 0
   else
      echo "$service_name not installed"
      return 1
   fi
}

# Function to start a service
start_service() {
   service_name=$1
   if is_service_installed "$service_name"; then
      echo "Starting $service_name..."
      service "$service_name" start
   fi
}

# Check and start Apache
start_service "apache2"

# Check and start MySQL
start_service "mysql"

# Function to handle termination signals
cleanup() {
   echo "Received termination signal. Exiting..."
   exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Add a user prompt loop to allow the user to decide when to exit
while true; do
   read -p "Press 'q' to quit the script: " input
   if [[ "$input" == "q" ]]; then
      break # Exit the loop if the user enters 'q'
   fi
done
