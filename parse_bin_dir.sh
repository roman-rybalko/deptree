#!/bin/sh

while [ -n "$1" ]; do
    for bin in "$1"/*; do
        [ -f "$bin" ] || continue
        case "$bin" in
            *.so)
                ;;
            *)
                [ -x "$bin" ] || continue
                ;;
        esac
        printf "$bin:\t"
        ./parse_bin.pl "$bin" dbi:SQLite:dbname=test.sqlite 2>>parse_bin.log
    done
    shift
done
