#!/bin/sh

while [ -n "$1" ]; do
    for apk in "$1"/*.apk; do
        [ -e "$apk" ] || continue
        printf "$apk:\t"
        ./parse_apk.pl "$apk" dbi:SQLite:dbname=test.sqlite 2>parse_apk.log
    done
    shift
done
