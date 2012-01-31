#!/bin/sh

dir="$1"
for lib in "$dir"/*.so; do
    [ -e "$lib" ] || continue
    ./parse_lib.pl "$lib" dbi:SQLite:dbname=test.sqlite 2>parse_lib.log
done
