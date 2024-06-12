FROM ubuntu:24.04

# Create directories
RUN mkdir -p /etc/apache2/sites-available
RUN mkdir -p /etc/apache2/ssl
RUN mkdir -p /srv/www
RUN mkdir -p /var/lib/mysql

# Copy scripts and set permission to execute
COPY scripts/lamp-setup-24.sh /lamp-setup.sh
COPY scripts/start.sh /start.sh
COPY ssl/ssl.cnf /etc/apache2/ssl/ssl.cnf
COPY ssl/root.pem /etc/apache2/ssl/root.pem
COPY ssl/root.key /etc/apache2/ssl/root.key
RUN chmod +x /start.sh
RUN chmod +x /lamp-setup.sh
RUN /lamp-setup.sh

# Run the start script on every boot
CMD /usr/bin/sudo /start.sh

# Set www-data as the default user
USER www-data