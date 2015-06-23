#!/bin/bash
# Wrapper for utils/setup.php to import a bunch of non overlapping  osm.pbf files
# after merging them. We're not sure of the result if the files are overlapping.
set -e
args=`getopt o: $*`

if [ $? != 0 ]; then
  echo "Usage: $0 -o mergefile.osm.pbf file.osm.pbf http://url/to/file.osm.pbf ..."
  exit 2
fi

pbf_to_osm () {
  # todo parallelize this to make it run faster
  for file; do
    osm_file=$(echo $file | sed -E 's/.pbf$//')
    osmconvert $file > $osm_file
    echo -n "$osm_file "
  done
}

merge_osm_files () {
  local merge_file=`mktemp -t merged.XXXX.osm`
  local cmd="osmosis "
  for osm_file; do
    cmd="$cmd --rx $osm_file "
  done
  cmd="$cmd --merge --wx $merge_file"
  $cmd
  echo $merge_file
}

set -- $args

for i
do
  case "$i"
  in
      -o)
	  mergefile_pbf=$2; shift; shift;;
      --)
	  shift; break;;
  esac
done


declare -a pbf_files
i=0
for uri in $@; do
  case "$uri"
  in
	http://*.osm.pbf)
	    # extract file name and download it
	    filename=$(echo $uri | sed -E 's!http://.*?/([^/]+$)!\1!')
	    echo "downloading $filename ..."
	    curl -fs# -o $filename $uri
	    pbf_files[$i]=$filename;;
	*.osm.pbf)
	    if [ ! -f $uri ]; then
	       echo "File not found $uri"
	       exit 2
	    fi
	    pbf_files[$i]=$uri;;
  esac
  i=$(( i + 1 ))
done
osm_files=$(pbf_to_osm ${pbf_files[*]})
echo "merging $osm_files"
merged=$(merge_osm_files $osm_files)
echo "files merged into $merged"
echo "converting to pbf"
if [ -z "$mergefile_pbf" ]; then
  mergefile_pbf="${merged}.pbf"
fi
osmconvert $merged -o=$mergefile_pbf
echo "file converted $mergefile_pbf"
chown nominatim $mergefile_pbf
