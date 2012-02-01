#!/bin/sh -xe

name=test.sqlite
idx=1
while [ -e $name.$idx ]; do idx=`expr $idx + 1`; done
while [ $idx -gt 1 ]; do nidx=`expr $idx - 1`; mv $name.$nidx $name.$idx; idx=$nidx; done
mv $name $name.1
sqlite3 test.sqlite < schema.sql
