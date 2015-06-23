# Nominatim Docker

Run [http://wiki.openstreetmap.org/wiki/Nominatim](http://wiki.openstreetmap.org/wiki/Nominatim) in a docker container. Clones the current master and builds it. This is always the latest version, be cautious as it may be unstable.

Uses Ubuntu 14.04 and PostgreSQL 9.3

# Building

To rebuild the image locally execute

```
docker build -t nominatim .
```

# Running

By default the container exposes port `8080` To run the container execute
The environment variables NOMINATIM_HOST and NOMINATIM_PORT can be set if you
want to expose the site on a public address.

```
# remove any existing containers
docker rm -f nominatim_container || echo "nominatim_container not found, skipping removal"
docker run -p 8080:8080 --name nominatim_container --detach nominatim
# expose on a public address
docker run -e NOMINATIM_HOST=my-public-address -p 8080:8080 --name nominatim_container --detach nominatim
```

Check the logs of the running container

```
docker logs nominatim_container
```

Stop the container
```
docker stop nominatim_container
```
# Importing files

First get the files

```
docker exec -ti nominatim_container wget -P /app/ \
  http://download.geofabrik.de/europe/monaco-latest.osm.pbf
```
Invoke setup.php

```
docker exec -ti nominatim_container sudo -u nominatim /app/nominatim/utils/setup.php --all \
  --threads 2 --osm-file path/to/osm-file-on-docker
```


# Merging files

Sometimes you want to merge some osm files before creating the database.
It's simple with this command.

```
docker exec -ti nominatim_container /app/nominatim/merge-pbf.sh \
  -o /app/monaco+andorra.osm.pbf
  http://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  http://download.geofabrik.de/europe/andorra-latest.osm.pbf
```

# Updating the database

You can update the database with the following commands
```
# first get the osm file you want to add to your system (not pbf)
docker exec -ti nominatim_container wget -P /app/ \
  http://download.geofabrik.de/europe/monaco-latest.osm.pbf
# convert it
docker exec -ti nominatim_container osmconvert /app/monaco-latest.osm.pbf \
    -o=/app/monaco-latest.osm
# call update.php
docker exec -ti nominatim_container sudo -u nominatim \
  /app/nominatim/utils/update.php --import-file /app/monaco-latest.osm --index
```

Connect to the nominatim webserver with curl. If this succeeds, open [http://localhost:8080/](http:/localhost:8080) in a web browser

```
curl "http://localhost:8080"
```
