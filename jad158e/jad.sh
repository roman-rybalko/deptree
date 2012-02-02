#!/bin/sh

ulimit -t 15
ulimit -c 0
echo "jad params: $@" 1>&2
`dirname $0`/jad "$@"
echo "jad exitcode: $?" 1>&2
exit 0
