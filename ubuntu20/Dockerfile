FROM ubuntu:20.04

RUN mkdir -p /etc/apache2/sites-available
RUN mkdir -p /srv/www
RUN mkdir -p /var/lib/mysql

COPY scripts/lamp-setup-20.sh /lamp-setup.sh
COPY scripts/start.sh /start.sh
COPY scripts/site-setup.sh /srv/www/site-setup.sh
COPY scripts/file-permissions.sh /srv/www/file-permissions.sh
