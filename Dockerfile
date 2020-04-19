FROM debian:buster

# Ensure that all required debian packages are installed
RUN \
    apt-get -y -q update \
    && apt-get -y -q --no-install-recommends install \
        apache2 \
        curl \
		ca-certificates \
        emacs \
        ffmpeg \
        gdb \
        ghostscript \
        git \
        imagemagick \
        libapr1-dbg \
        libaprutil1-dbg \
        msmtp-mta \
        php \
        php7.3-mbstring \
        php-curl \
        php-json \
        postgresql-client \
        php-pgsql \
        pngquant \
        vim \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /var/log/dpkg.log

# Install confd configuration file generator
RUN curl -#L https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 -o /usr/local/bin/confd \
    && chmod 755 /usr/local/bin/confd \
    && mkdir -p /etc/confd/conf.d \
    && mkdir -p /etc/confd/templates \
    && touch /etc/confd/confd.toml

# Prepare for environment-configured Apache and PHP setup
RUN rm /etc/php/7.3/apache2/conf.d/* \
    && rm /etc/php/7.3/cli/conf.d/* \
    && phpenmod pdo pdo_pgsql curl json mbstring \
    && phpenmod -s ALL opcache \
    && rm /etc/apache2/conf-enabled/* \
    && rm /etc/apache2/mods-enabled/* \
    && a2enmod mpm_prefork mime negotiation rewrite php7.3 env dir auth_basic authn_file authz_user authz_host access_compat \
    && rm /etc/apache2/sites-enabled/000-default.conf

EXPOSE 8080

ENV LANG=C
ENV APACHE_LOCK_DIR         /var/lock/apache2
ENV APACHE_RUN_DIR          /var/run/apache2
ENV APACHE_PID_FILE         ${APACHE_RUN_DIR}/apache2.pid
ENV APACHE_LOG_DIR          /var/log/apache2
ENV APACHE_RUN_USER         www-data
ENV APACHE_RUN_GROUP        www-data
ENV APACHE_MAX_REQUEST_WORKERS 32
ENV APACHE_MAX_CONNECTIONS_PER_CHILD 1024
ENV APACHE_ALLOW_OVERRIDE   None
ENV APACHE_ALLOW_ENCODED_SLASHES Off
ENV APACHE_ERRORLOG         "/dev/stdout"
ENV APACHE_CUSTOMLOG        ""
ENV APACHE_LOGLEVEL         error
ENV PHP_TIMEZONE            UTC
ENV PHP_MBSTRING_FUNC_OVERLOAD 0
ENV PHP_ALWAYS_POPULATE_RAW_POST_DATA 0

COPY apache2-coredumps.conf /etc/security/limits.d/apache2-coredumps.conf
RUN mkdir /tmp/apache2-coredumps && chown ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /tmp/apache2-coredumps && chmod 700 /tmp/apache2-coredumps
COPY coredump.conf /etc/apache2/conf-available/coredump.conf
COPY .gdbinit /root/.gdbinit

COPY confd/php.cli.toml /etc/confd/conf.d/
COPY confd/templates/php7.cli.ini.tmpl /etc/confd/templates/
COPY confd/php.apache2.toml /etc/confd/conf.d/
COPY confd/templates/php.apache2.ini.tmpl /etc/confd/templates/
COPY confd/apache2.toml /etc/confd/conf.d/
COPY confd/templates/apache2.conf.tmpl /etc/confd/templates/
COPY confd/mpm_prefork.toml /etc/confd/conf.d/
COPY confd/templates/mpm_prefork.conf.tmpl /etc/confd/templates/
RUN /usr/local/bin/confd -onetime -backend env
COPY confd/msmtprc.toml /etc/confd/conf.d/
COPY confd/templates/msmtprc.tmpl /etc/confd/templates/

COPY ports.conf /etc/apache2/ports.conf

COPY apache2-mods/remoteip.conf /etc/apache2/mods-available/remoteip.conf
RUN a2enmod remoteip

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2"]
