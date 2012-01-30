#!/bin/sh

dir="$1"
for apk in "$dir"/*.apk; do
    [ -e "$apk" ] || continue
    ./parse_apk.pl "$apk" dbi:SQLite:dbname=test.sqlite 2>parse_apk.log
done
