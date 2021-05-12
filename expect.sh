#!/bin/bash

set -e

THIS=$0
cd `dirname $THIS`
while [ -h "$THIS" ];do
	THIS=`ls -l $THIS | sed 's/.* -> \(.*\)$/\1/g'`
	cd `dirname $THIS`
done

if [ "`cat /nfs/mount | grep ^$1 | wc -l`" == "1" ];then
	MODEL=`cat /nfs/mount | grep ^$1 | awk '{print $4}'`
	python3 ./jinja.py $MODEL> /tmp/.service.sh
	expect .expect.exp $1
else
	echo "Can not find host($1)'s settings."
fi
