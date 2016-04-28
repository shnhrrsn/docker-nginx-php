FROM ubuntu:16.04

ENV PHPBREW_ROOT /opt/phpbrew
ENV PHP_VERSION 7.0.5
ENV PHP_PATH ${PHPBREW_ROOT}/php/php-${PHP_VERSION}
ENV PHP_BIN_PATH ${PHPBREW_ROOT}/php/php-${PHP_VERSION}/bin
ENV PHP_VARIANTS +default+dbs+mb+mcrypt+openssl+intl+cgi+fpm

# Common deps
RUN apt-get update && apt-get install -y \
	autoconf \
	automake \
	bison \
	build-essential \
	curl \
	gettext \
	git \
	libbz2-dev \
	libcurl3-openssl-dev \
	libfreetype6 \
	libfreetype6-dev \
	libgd-dev \
	libgd3 \
	libgettextpo-dev \
	libgettextpo0 \
	libicu-dev \
	libjpeg-dev \
	libjpeg8  \
	libjpeg8-dev \
	libltdl-dev \
	libltdl7 \
	libmcrypt-dev \
	libmcrypt4 \
	libmhash-dev \
	libmhash2 \
	libpng12-0 \
	libpng12-dev \
	libpq-dev \
	libreadline-dev \
	libssl-dev \
	libxml2 \
	libxml2-dev \
	libxpm4 \
	libxslt1-dev \
	openssl \
	php \
	php-cli \
	php-dev \
	php-pear \
	re2c

# Install zsh
RUN apt-get update && apt-get install -y zsh \
	&& (sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true) \
	&& chsh `env zsh`

# Install phpbrew
RUN curl -L -O https://github.com/phpbrew/phpbrew/raw/master/phpbrew \
	&& chmod +x phpbrew && mv phpbrew /usr/local/bin/phpbrew \
	&& PHPBREW_ROOT=${PHPBREW_ROOT} phpbrew init \
	&& echo 'source ~/.phpbrew/bashrc' >> ~/.bashrc \
	&& echo 'source ~/.phpbrew/bashrc' >> ~/.zshrc

# Install php
RUN phpbrew install ${PHP_VERSION} ${PHP_VARIANTS}
RUN phpbrew switch php-${PHP_VERSION} \
	&& mkdir -p "${PHP_PATH}/var/db" \
	&& echo "date.timezone = UTC" >> "${PHP_PATH}/etc/php.ini" \
	&& bash -c "source ~/.phpbrew/bashrc; phpbrew use ${PHP_VERSION}; phpbrew ext install apcu 5.1.3" \
	&& bash -c "source ~/.phpbrew/bashrc; phpbrew use ${PHP_VERSION}; phpbrew ext install iconv" \
	&& ln -s ${PHP_PATH} ${PHPBREW_ROOT}/php/php-current \
	&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${PHP_PATH}/etc/php-fpm.conf

COPY php/www.conf ${PHP_PATH}/etc/php-fpm.d/www.conf

# Install nginx
RUN apt-get update && apt-get install -y nginx \
	&& mkdir -p /var/www \
	&& chown www-data:www-data /var/www \
	&& service nginx stop \
	&& update-rc.d -f nginx remove \
	&& rm -f /etc/init.d/nginx \
	&& echo "daemon off;" >> /etc/nginx/nginx.conf \
	&& chown www-data:www-data ${PHP_PATH}/var/log
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/phpfpm_params /etc/nginx/phpfpm_params

# Install supervisor
RUN apt-get update \
	&& apt-get install -y supervisor \
	&& service supervisor stop \
	&& update-rc.d -f supervisor remove \
	&& rm -f /etc/init.d/supervisor

COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf

VOLUME /var/www
WORKDIR /var/www
EXPOSE 80
EXPOSE 443

CMD ["/usr/bin/supervisord",  "-n", "-c", "/etc/supervisor/supervisord.conf"]
