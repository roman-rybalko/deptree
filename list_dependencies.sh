#!/bin/sh -e

./list_dependencies.pl "$1" dbi:SQLite:dbname=test.sqlite
