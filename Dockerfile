FROM wordpress

# Install requirements for versionpress support
RUN apt-get update \
  && apt-get install -y git sudo less mysql-client unzip \
  && rm -rf /var/lib/apt/lists/*

RUN echo 'www-data  ALL=(ALL:ALL) ALL' >> /etc/sudoers

# Add WP-CLI 
RUN curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
COPY wp-su.sh /bin/wp
RUN chmod +x /bin/wp-cli.phar

# Update WP-CLI to nightly to fix some errors with WordPress 4.5.2
RUN chmod a+w /bin && chmod a+w /bin/wp-cli.phar
RUN wp cli update --nightly --yes
RUN chmod g-w,o-w /bin && chmod g-w,o-w /bin/wp-cli.phar

# Download Versionpress
ENV VERSIONPRESS_VERSION 3.0.1
RUN curl -L -o /versionpress.zip https://github.com/versionpress/versionpress/releases/download/$VERSIONPRESS_VERSION/versionpress-$VERSIONPRESS_VERSION.zip \
    && unzip /versionpress.zip -d /usr/src/wordpress/wp-content/plugins/ \
    && rm /versionpress.zip \
    && chown -R www-data:www-data /usr/src/wordpress/wp-content/plugins/versionpress

# Install xdebug
RUN pecl install xdebug
COPY xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Make caching optional
ENV WORDPRESS_OPCACHE 'off'

# Update entrypoint
COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
