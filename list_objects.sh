#!/bin/sh -xe

sqlite3 test.sqlite "select name from objects"
