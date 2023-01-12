FROM ubuntu:18.04

RUN mkdir -p /etc/apache2/sites-available
RUN mkdir -p /srv/www
RUN mkdir -p /var/lib/mysql

COPY scripts/lamp-setup-18.sh /lamp-setup.sh
COPY scripts/start.sh /start.sh
