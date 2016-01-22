FROM debian:7
MAINTAINER Tuomas Jaakola <tuomas.jaakola@iki.fi>

LABEL description="Environment for TOE"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get install -y \
    git \
    mapnik-utils \
    nginx \
    php5-fpm \
    php5-gd \
    php5-sqlite \
    postgis \
    postgresql-9.1-postgis \
    postgresql-contrib-9.1 \
    python-cairo \
    python-cairo-dev \
    python-mapnik2 \
    python2.7-dev \
    supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /opt && \
    git clone https://github.com/iqqmut/toe

COPY config.php /opt/toe/

COPY nginx.conf /etc/nginx/
COPY default.conf /etc/nginx/conf.d/

COPY supervisord.conf /etc/supervisor/

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

VOLUME ["/opt/toe"]

EXPOSE 80

# Use supervisord to launch nginx and php5-fpm
CMD ["/usr/bin/supervisord"]
