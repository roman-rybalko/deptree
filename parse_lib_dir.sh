#!/bin/sh

while [ -n "$1" ]; do
    for lib in "$1"/*.so; do
        [ -e "$lib" ] || continue
        echo -n "$lib: "
        ./parse_lib.pl "$lib" dbi:SQLite:dbname=test.sqlite 2>parse_lib.log
    done
    shift
done
