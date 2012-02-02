#!/bin/sh -e

./list_symbols.pl "$1" dbi:SQLite:dbname=test.sqlite
