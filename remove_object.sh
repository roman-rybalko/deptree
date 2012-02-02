#!/bin/sh -e

obj="$1"
[ -n "$obj" ]
shift
./remove_object.pl "$obj" dbi:SQLite:dbname=test.sqlite "" "" "$@"
