#!/bin/ksh
emgr -P | awk '{print $3}' | grep -v LABEL | grep -v "=" > /tmp/aix-fix
for i in `cat /tmp/aix-fix`
do 
emgr -r -L $i
done
