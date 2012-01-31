#!/bin/sh
PARAMS=
[ -n "$SMALI_BOOTCLASSPATH_DIR" ] && PARAMS="$PARAMS -d $SMALI_BOOTCLASSPATH_DIR"
[ -n "$SMALI_APILVL" ] && PARAMS="$PARAMS -a $SMALI_APILVL"
java -jar `dirname $0`/baksmali-1.3.2.jar $PARAMS "$@" && exit 0
[ -n "$SMALI_BOOTCLASSPATH" ] && PARAMS="$PARAMS -c $SMALI_BOOTCLASSPATH"
java -jar `dirname $0`/baksmali-1.3.2.jar $PARAMS "$@" && exit 0
