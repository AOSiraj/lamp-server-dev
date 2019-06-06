FROM php:7.2-apache

############################################################################
# Install requried libraries, should be the same across dev, QA, etc...
############################################################################
RUN apt-get update \
    && apt-get install -y curl wget git zip unzip zlib1g-dev libpng-dev \
       gnupg2 libldap2-dev ssl-cert libzip-dev libssl-dev \
    && apt-get autoremove \
    && apt-get clean \
    && yes '' | pecl install -f redis \
       && rm -rf /tmp/pear \
       && docker-php-ext-enable redis \
    && a2enmod rewrite ssl \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install gd zip ldap

############################################################################
# Install SSH Deploy keys
############################################################################
ENV GIT_SSL_NO_VERIFY="1"
ADD _deploy_keys/ /root/.ssh/
RUN chmod 700 /root/.ssh \
    && chmod 644 /root/.ssh/config \
    && chmod 644 /root/.ssh/id_rsa.pub \
    && chmod 600 /root/.ssh/id_rsa


############################################################################
# Install composer
############################################################################
RUN cd ~ \
    && wget https://getcomposer.org/installer \
    && php installer \
    && rm installer \
    && mkdir bin \
    && mv composer.phar bin/composer \
    && chmod u+x bin/composer
# Add our script files so they can be found
ENV PATH /root/bin:~/.composer/vendor/bin:$PATH

############################################################################
# Isntall Codeception native
############################################################################
RUN curl -LsS https://codeception.com/codecept.phar -o /usr/local/bin/codecept \
    && chmod a+x /usr/local/bin/codecept

############################################################################
# Configure local webserver
############################################################################
RUN a2enmod vhost_alias http2 headers rewrite ssl
#    && rm -f /etc/apache2/sites-enabled/*
ADD assets/apache2/sites/ /etc/apache2/sites-enabled/
ADD assets/ssl/certs/ /etc/ssl/certs/
ADD assets/ssl/private/ /etc/ssl/private/
RUN chown :ssl-cert /etc/ssl/private/loopback.world.privkey.pem \
    && chmod 640 /etc/ssl/private/loopback.world.privkey.pem \
    && usermod -aG ssl-cert www-data


############################################################################
############################################################################
################### Begin Development setup ################################
############################################################################
############################################################################

############################################################################
# Update Linux app database and install Linux dev tools
############################################################################
RUN apt-get update \
    && apt-get install -y net-tools curl wget zip unzip zlib1g-dev \
       libpng-dev joe gnupg2 libldap2-dev inetutils-ping

#############################################################################
# Setup PHP developer tools
#############################################################################
RUN docker-php-ext-install gd zip ldap gettext \
    && composer global require phpunit/phpunit \
       phing/phing \
       sebastian/phpcpd \
       phploc/phploc \
       phpmd/phpmd \
       squizlabs/php_codesniffer

#############################################################################
# Setup Redis server
#############################################################################
#RUN apt-get install -y redis-server

##############################################################################
## Setup MariaDB
##############################################################################
RUN apt-get install -y mariadb-server mariadb-client \
    && docker-php-ext-install pdo pdo_mysql mysqli \
    && /bin/bash -c "/usr/bin/mysqld_safe &" \
        && sleep 5 \
        && mysql -u root -pnaked -e "CREATE USER 'root'@'%' IDENTIFIED BY 'naked';" \
        && mysql -u root -pnaked -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' REQUIRE NONE WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;" \
        && mysql -u root -pnaked -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'naked' WITH GRANT OPTION;" \
        && sed -i '/bind-address/c\bind-address\t\t= 0.0.0.0' /etc/mysql/my.cnf \
        && sed -Ei "s/bind-address.*/bind-address=0.0.0.0/g" /etc/mysql/mariadb.conf.d/50-server.cnf


#############################################################################
## Setup XDebug, always try and start XDebug connection to host.docker.internal
#############################################################################
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini


############################################################################
# Setup Docker init, use this for Development ONLY!!!!!
############################################################################
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
# Add custom init script
ADD assets/scripts/init.sh /etc/init.sh
ENTRYPOINT ["/tini", "/etc/init.sh"]
RUN chmod +x /tini \
    && chmod +x /etc/init.sh

# Varables to make development easer.
# CLI XDebug
ENV XDEBUG_CONFIG remote_host=host.docker.internal remote_port=9000 remote_autostart=1

ENV MYSQL_HOST localhost
ENV MYSQL_USER root
ENV MYSQL_PWD naked

EXPOSE 80 443 3000

WORKDIR /var/www