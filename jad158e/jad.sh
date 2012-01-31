#!/bin/sh

ulimit -t 15 -c 0
`dirname $0`/jad "$@"
exit 0
