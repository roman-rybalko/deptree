#!/bin/sh -xe

rom=$1
[ -d "$rom" ]
./parse_bin_dir.sh $rom/lib $rom/lib/*/ $rom/usr/lib $rom/usr/lib/*/ $rom/bin $rom/sbin $rom/xbin \
    $rom/usr/bin $rom/usr/sbin $rom/usr/xbin $rom/usr/local/bin $rom/usr/local/sbin $rom/usr/local/xbin
./parse_jar_dir.sh $rom/framework $rom/framework/*/
./parse_apk_dir.sh $rom/app $rom/app-private
