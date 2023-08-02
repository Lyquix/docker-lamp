FROM ubuntu:22.04

# Create directories
RUN mkdir -p /etc/apache2/sites-available
RUN mkdir -p /srv/www
RUN mkdir -p /var/lib/mysql

# Copy scripts and set permission to execute
COPY scripts/lamp-setup-22.sh /lamp-setup.sh
COPY scripts/start.sh /start.sh
RUN chmod +x /lamp-setup.sh
RUN chmod +x /start.sh

# Install sudo and set www-data as sudoer
RUN apt update
RUN apt install -y sudo
RUN echo "www-data    ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

# Run the start script on every boot
CMD /usr/bin/sudo /start.sh

# Set www-data as the default user
USER www-data