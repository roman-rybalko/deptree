#!/bin/sh

while [ -n "$1" ]; do
    for jar in "$1"/*.jar; do
        [ -e "$jar" ] || continue
        printf "$jar:\t"
        ./parse_jar.pl "$jar" dbi:SQLite:dbname=test.sqlite 2>>parse_jar.log
    done
    shift
done
