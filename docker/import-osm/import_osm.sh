#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

# For backward compatibility, allow both PG* and POSTGRES_* forms,
# with the non-standard POSTGRES_* form taking precedence.
# An error will be raised if neither form is given, except for the PGPORT
export PGHOST="${POSTGRES_HOST:-${PGHOST?}}"
export PGDATABASE="${POSTGRES_DB:-${PGDATABASE?}}"
export PGUSER="${POSTGRES_USER:-${PGUSER?}}"
export PGPASSWORD="${POSTGRES_PASSWORD:-${PGPASSWORD?}}"
export PGPORT="${POSTGRES_PORT:-${PGPORT:-5432}}"


: "${DIFF_MODE:=true}"


function import_pbf() {
    local pbf_file="$1"
    local diff_flag=""
    if [ "$DIFF_MODE" = true ]; then
        diff_flag="-diff"
        echo "Importing in diff mode"
    else
        echo "Importing in normal mode"
    fi

    local cache_flag=""
    if [ -d $IMPOSM_CACHE_DIR ]; then
        # Cache dir exists
        if [ -z "$(ls -A $IMPOSM_CACHE_DIR)" ]; then
            # Cache dir empty
            cache_flag="-overwritecache"
            echo "No cache contents found, assuming first import and overwriting cache/db"
        else
            # Cache dir not empty
            cache_flag="-appendcache"
            echo "Cache contents found, appending data to cache/db."
            echo " If you do not want this please clear the cache directory before running this container"
        fi
    else
        # This should never happen
        cache_flag="-overwritecache"
        echo "No cache contents found, assuming first import and overwriting cache/db"
    fi

    imposm import \
        -connection "postgis://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE" \
        -mapping "$MAPPING_YAML" \
        -diffdir "$DIFF_DIR" \
        -cachedir "$IMPOSM_CACHE_DIR" \
        $cache_flag \
        -read "$pbf_file" \
        -deployproduction \
        -write $diff_flag \
        -optimize \
        -config "$CONFIG_JSON"
}

function import_osm_with_first_pbf() {
    if [ "$(ls -A $IMPORT_DIR/*.pbf 2> /dev/null)" ]; then
        local pbf_file
        for pbf_file in "$IMPORT_DIR"/*.pbf; do
            import_pbf "$pbf_file"
            break
        done
    else
        echo "No PBF files for import found."
        echo "Please mount the $IMPORT_DIR volume to a folder containing OSM PBF files."
        exit 1
    fi
}

import_osm_with_first_pbf
