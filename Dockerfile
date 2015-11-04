FROM ubuntu:14.04
MAINTAINER Jan Nonnen <helvalius@gmail.com>

RUN apt-get update

# Install basic software
RUN apt-get -y install wget curl sudo bc

# Note: libgeos++-dev is included here too (the nominatim install page suggests installing it if there is a problem with the 'pear install DB' below - it seems safe to install it anyway)
RUN apt-get -y install build-essential autoconf-archive
RUN apt-get -y install gcc git osmosis osmctools
RUN apt-get -y install libxml2-dev libgeos-dev libpq-dev libbz2-dev libtool automake libproj-dev
RUN apt-get -y install proj-bin libgeos-c1 libgeos++-dev

# Install Boost (required by osm2pqsql)
RUN apt-get -y install autoconf make g++ libboost-dev \
  libboost-system-dev libboost-filesystem-dev libboost-thread-dev

# Install PHP5
RUN apt-get -y install php5 php-pear php5-pgsql php5-json php-db

# Install Postgres, PostGIS and dependencies
RUN apt-get -y install postgresql postgis postgresql-contrib postgresql-9.3-postgis-2.1 postgresql-server-dev-9.3

# Install Apache
RUN apt-get -y install apache2

# Add Protobuf support
RUN apt-get -y install libprotobuf-c0-dev protobuf-c-compiler

# Used by nominatim
RUN apt-get -y install libexpat1-dev

# Install nominatim
RUN pear install DB
RUN useradd -m -p password1234 nominatim
RUN mkdir -p /app/nominatim
RUN git clone --recursive https://github.com/twain47/Nominatim.git /app/nominatim
RUN cd /app/nominatim
WORKDIR /app/nominatim
RUN ./autogen.sh
RUN ./configure
RUN make

# Configure postgresql
RUN service postgresql start && sleep 10 && \
  pg_dropcluster --stop 9.3 main
RUN service postgresql start && sleep 10 && \
  pg_createcluster --start -e UTF-8 9.3 main

RUN service postgresql start && sleep 10 && \
  sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim && \
  sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data && \
  sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim"

WORKDIR /app/nominatim

ADD local.php /app/nominatim/settings/local.php
ADD merge-pbf.sh /app/nominatim/

RUN mkdir -p /var/www/nominatim
RUN ./utils/setup.php --create-website /var/www/nominatim

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/9.3/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432

# Add the site and start apache
ADD 400-nominatim.conf /etc/apache2/sites-available/400-nominatim.conf
ADD httpd.conf /etc/apache2/
RUN service apache2 start && \
  a2ensite 400-nominatim.conf && \
  /etc/init.d/apache2 reload

# Expose the HTTP port
EXPOSE 8080

ADD configPostgresql.sh /app/nominatim/configPostgresql.sh
WORKDIR /app/nominatim
RUN chmod +x ./configPostgresql.sh
ADD start.sh /app/nominatim/start.sh
RUN chmod +x /app/nominatim/start.sh
CMD /app/nominatim/start.sh
