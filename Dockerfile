FROM debian:stretch
MAINTAINER Tuomas Jaakola <tuomas.jaakola@iki.fi>

LABEL description="Environment for TOE with Mapnik 3"

ENV MAPNIK_VERSION 3.0.9
ENV CARTO_VERSION 2.37.1
ENV TEST_MAP isle-of-man-latest

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get install -y locales

# Set the locale. This affects the encoding of the Postgresql template # databases.
ENV LANG C.UTF-8
RUN update-locale LANG=C.UTF-8

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bzip2 \
    build-essential \
    curl \
    git \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-iostreams-dev \
    libboost-thread-dev \
    libboost-python-dev \
    libboost-program-options-dev \
    libboost-regex-dev \
    libcairo-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libpq-dev \
    libproj-dev \
    libtiff-dev \
    libwebp-dev \
    libgdal-dev \
    locales \
    nginx \
    npm \
    osm2pgsql \
    php5-fpm \
    php5-gd \
    php5-sqlite \
    postgis \
    postgresql-9.5-postgis-scripts \
    postgresql-contrib-9.5 \
    python-cairo \
    python-cairo-dev \
    python-urllib3 \
    python-dev \
    python-setuptools \
    subversion \
    supervisor \
    unzip \
    virtualenv \
    wget && \
    rm -rf /var/lib/apt/lists/* /var/tmp/*

# Install patched Mapnik by building from sources
#ADD https://github.com/mapnik/mapnik/archive/v${MAPNIK_VERSION}.tar.gz /opt/osm/
RUN mkdir -p /opt/osm && \
    cd /opt/osm && \
    git clone https://github.com/iqqmuT/mapnik.git mapnik-${MAPNIK_VERSION} && \
    #cd /opt/osm && \
    #tar xzf v${MAPNIK_VERSION}.tar.gz && \
    #rm v${MAPNIK_VERSION}.tar.gz && \
    cd mapnik-${MAPNIK_VERSION} && \
    git submodule update --init && \
    ./configure && \
    JOBS=4 make && \
    make install

# Install Mapnik python bindings
RUN cd /opt/osm/mapnik-${MAPNIK_VERSION} && \
    git clone https://github.com/mapnik/python-mapnik.git python && \
    cd python && \
    PYCAIRO=true python setup.py install

RUN npm install -g carto && \
    # needed for debian nodejs env
    ln -s /usr/bin/nodejs /usr/bin/node

RUN cd /opt && \
    git clone https://github.com/iqqmut/toe && \
    # PHP QR Code library
    curl -L http://sourceforge.net/projects/phpqrcode/files/releases/phpqrcode-2010100721_1.1.4.zip/download > /tmp/phpqrcode.zip && \
    cd toe/export/lib && \
    unzip /tmp/phpqrcode.zip

COPY config.php /opt/toe/
COPY toe-export-config.php /opt/toe/export/config.php
COPY nginx.conf /etc/nginx/
COPY default.conf /etc/nginx/conf.d/
COPY supervisord.conf /etc/supervisor/

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/display_errors = Off/display_errors = On/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
# run php as postgres user so it has access to db
sed -i -e "s/user\s*=\s*www-data/user = postgres/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/^group\s*=\s*www-data/group = postgres/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/;listen.mode\s*=\s*0660/listen.mode = 0666/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

# PostgreSQL tuning
# http://wiki.openstreetmap.org/wiki/PostgreSQL
RUN echo "maintenance_work_mem = 256MB" >> /etc/postgresql/9.5/main/postgresql.conf && \
    echo "work_mem = 256MB" >> /etc/postgresql/9.5/main/postgresql.conf && \
    echo "autovacuum = off" >> /etc/postgresql/9.5/main/postgresql.conf && \
    # Allow all connections
    sed -i -e "s/peer/trust/g" /etc/postgresql/9.5/main/pg_hba.conf && \
    sed -i -e "s/md5/trust/g" /etc/postgresql/9.5/main/pg_hba.conf && \
    echo "listen_addresses='*'" >> /etc/postgresql/9.5/main/postgresql.conf

# https://github.com/gravitystorm/openstreetmap-carto/blob/master/INSTALL.md
ADD https://github.com/gravitystorm/openstreetmap-carto/archive/v${CARTO_VERSION}.tar.gz /opt/osm/
RUN cd /opt/osm && \
    tar xzf v${CARTO_VERSION}.tar.gz && \
    rm v${CARTO_VERSION}.tar.gz && \
    cd openstreetmap-carto-${CARTO_VERSION} && \
    ./get-shapefiles.sh && \
    carto project.mml > mapnik.xml

# Install test map
ADD http://download.geofabrik.de/europe/${TEST_MAP}.osm.pbf /opt/osm/maps/
RUN chmod a+r -R /opt/osm/maps && \
    rm -rf /tmp/*

USER postgres

# http://wiki.openstreetmap.org/wiki/PostGIS/Installation
RUN /etc/init.d/postgresql start && \
    createuser gisuser && \
    createdb --encoding=UTF8 --owner=gisuser gis && \
    psql -d gis -c "CREATE EXTENSION postgis;" && \
    psql -d gis -c "CREATE EXTENSION postgis_topology;"

RUN /etc/init.d/postgresql start && \
    # wait for postgresql starting up
    sleep 10 && \
    cd /opt/osm/openstreetmap-carto-${CARTO_VERSION} && \
    osm2pgsql -U gisuser -d gis /opt/osm/maps/${TEST_MAP}.osm.pbf --style openstreetmap-carto.style && \
    /etc/init.d/postgresql stop

VOLUME ["/opt/toe"]

EXPOSE 80

USER root

# Use supervisord to launch nginx and php5-fpm
CMD ["/usr/bin/supervisord"]
