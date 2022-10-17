#!/bin/sh
set -e

FILE=$1
GEOLONIA_ACCESS_TOKEN=$2
OUT_DIR=$3

GH_REPOSITORY_NAME=$(echo $GITHUB_REPOSITORY | cut -d'/' -f2)
TILES_OUT_DIR=$OUT_DIR/tiles
METADATA_JSON=$TILES_OUT_DIR/metadata.json
LAYER_NAME=data

mkdir -p $TILES_OUT_DIR

if [ $GEOLONIA_ACCESS_TOKEN ]; then
  GEOLONIA_ACCESS_TOKEN=$GEOLONIA_ACCESS_TOKEN geolonia locations upload $1
else

  TILE_MAXZOOM_OPTION=""

  # if geojson has one feature and geometry type is Point, set maxzoom to 14

  if [ $(cat $FILE | jq '.features | length') -eq 1 ]; then
    if [ $(cat $FILE | jq '.features[0].geometry.type') = '"Point"' ]; then
      TILE_MAXZOOM_OPTION="-z8"
      else
      TILE_MAXZOOM_OPTION="-zg"
    fi
  fi

  tippecanoe $TILE_MAXZOOM_OPTION \
    --force \
    --output-to-directory $TILES_OUT_DIR \
    --layer $LAYER_NAME \
    --drop-densest-as-needed \
    --no-tile-compression \
    $FILE

  find $TILES_OUT_DIR -name "*.pbf" -exec sh -c 'mv "$1" "${1%.pbf}".mvt' - '{}' \;

  if [ -f $METADATA_JSON ]
  then

    cat $METADATA_JSON | jq '{
      "tilejson": "3.0.0",
      name: .name,
      version: .version,
      description: .description,
      type: .type,
      format: "mvt",
      attribution: .attribution,
      minzoom: .minzoom | tonumber,
      maxzoom: .maxzoom | tonumber,
      center: .center | split(",") | map(tonumber),
      bounds: .bounds | split(",") | map(tonumber),
      "tiles": [
        "https://'${GITHUB_REPOSITORY_OWNER}'.github.io/'${GH_REPOSITORY_NAME}'/tiles/{z}/{x}/{y}.mvt"
      ]
    }' > $TILES_OUT_DIR/tiles.json

  fi

fi
