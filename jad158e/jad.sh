#!/bin/sh

ulimit -t 15
ulimit -c 0
`dirname $0`/jad "$@"
exit 0
