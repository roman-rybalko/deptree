#!/bin/sh -e

./list_objects.pl "$1" dbi:SQLite:dbname=test.sqlite
