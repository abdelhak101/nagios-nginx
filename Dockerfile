# Use a lightweight Nginx image as the base
FROM nginx:stable-alpine-perl

# Set build arguments and environment variables
ARG PHP_VERSION=83
ARG NAGIOS_VERSION=4.5.3
ARG NAGIOS_PLUGIN_VERSION=2.4.10

# Create Nagios user and command group, install necessary packages, configure PHP-FPM, 
# download and compile Nagios, and clean up in a single RUN command
RUN adduser -D -H nagios && \
    addgroup nagios nginx && \
    apk add --no-cache \
      build-base openssl-dev procps linux-headers \
      unzip apache2-utils \
      php${PHP_VERSION} php${PHP_VERSION}-fpm spawn-fcgi fcgiwrap \
      supervisor \
      autoconf automake && \
    cd /tmp && \
    wget -O nagioscore-nagios-${NAGIOS_VERSION}.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz && \
    wget --no-check-certificate -O nagios-plugins-release-${NAGIOS_PLUGIN_VERSION}.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-${NAGIOS_PLUGIN_VERSION}.tar.gz && \
    tar zxf nagioscore-nagios-${NAGIOS_VERSION}.tar.gz && \
    tar zxf nagios-plugins-release-${NAGIOS_PLUGIN_VERSION}.tar.gz && \
    cd nagioscore-nagios-${NAGIOS_VERSION} && \
    ./configure \
      --with-nagios-user=nginx \
      --with-nagios-group=nginx \
      --with-command-user=nginx \
      --with-command-group=nginx && \
    make all && \
    make install && \
    make install-init && \
    make install-config && \
    make install-commandmode && \
    make clean && \
    cd /tmp/nagios-plugins-release-${NAGIOS_PLUGIN_VERSION} && \
    ./tools/setup && \
    ./configure \
      --with-cgiurl=/usr/local/nagios \
      --prefix=/usr/local/nagios/sbin \
      --with-nagios-user=nginx \
      --with-nagios-group=nginx && \
    make && \
    make install && \
    make clean && \ 
    cd /tmp && \
    rm -rf nagioscore-nagios-${NAGIOS_VERSION} \
           nagios-plugins-release-${NAGIOS_PLUGIN_VERSION} \
           nagioscore-nagios-${NAGIOS_VERSION}.tar.gz \
           nagios-plugins-release-${NAGIOS_PLUGIN_VERSION}.tar.gz && \
    CONF_FILE="/etc/php${PHP_VERSION}/php-fpm.d/www.conf" && \
    sed -i 's|^listen = 127.0.0.1:9000|listen = /run/php-fpm.sock|' "$CONF_FILE" && \
    sed -i 's|^;listen = 127.0.0.1:9000|listen = /run/php-fpm.sock|' "$CONF_FILE" && \
    sed -i 's|^user = nobody|user = nginx|' "$CONF_FILE" && \
    sed -i 's|^group = nobody|group = nginx|' "$CONF_FILE" && \
    sed -i 's|^;security.limit_extensions = .php .php3 .php4 .php5 .php7|security.limit_extensions = .php .cgi|' "$CONF_FILE" && \
    sed -i 's|^security.limit_extensions = .php .php3 .php4 .php5 .php7|security.limit_extensions = .php .cgi|' "$CONF_FILE" && \
    mkdir /var/log/supervisor && \
    chown -R nginx:nginx /run /var/log/nginx /var/log/supervisor /var/log/php${PHP_VERSION} /var/cache /usr/local/nagios && \
    htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin 
    #&& \
#    apk del gcc make build-base openssl-dev unzip

# Copy configuration files
COPY nginx_default.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY phpinfo.php /usr/local/nagios/share/phpinfo.php

# Expose port 8080
EXPOSE 80

# Start supervisord to manage PHP-FPM and Nginx
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]