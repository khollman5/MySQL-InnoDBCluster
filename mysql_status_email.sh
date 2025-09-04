#!/bin/bash

# Usage: ./mysql_status.sh

MYSQLSH='mysqlsh --login-path=icadmin -h${HOSTNAME} --sqlc -e '
DIR=/root/MySQL

# Leaving nodes 1 (5 for moodle) as hosts to be inspected:
#for i in `cat mysql_hosts.txt | grep -Ev 'rtdb|02|03|06|07'`
for i in `cat ${DIR}/mysql_hosts.txt | grep -Ev 'rtdb|web|02|03|06|07'`
do
   echo '<p style="text-align: left; text-indent: 0px; background-color: #87CEEB; margin: 0px;">'
   echo '<span style="font-family: courier,monospace; font-size: 10pt; color: rgb(36, 36, 36);">&nbsp;</span></p>'
   echo '<p style="text-align: left; text-indent: 0px; background-color: #87CEEB; margin: 0px;">'
   echo '<span style="font-family: courier,monospace; font-size: 18pt; color: rgb(36, 36, 36);"><b>'
   echo "$i"
   echo '</b></span></p>'

   ssh -q $i "/mnt/backup/scripts/cluster_check_email.sh"
   echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
   echo '<span style="font-family: courier,monospace; font-size: 10pt; color: rgb(36, 36, 36);">&nbsp;</span></p>'
done

   echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
   echo '<span style="font-family: Calibri, sans-serif; font-size: 16pt; color: rgb(36, 36, 36);">MySQL Router restarts</span></p>'
for i in `cat ${DIR}/mysql_routers.txt`
do
  output=$(ssh -q "$i" "tail -400 /root/MySQL/RouterStatus.log | grep -B 1 -i restarting" | tr '\n' ' ')
  if [[ -n "$output" ]]; then
    echo '<p style="text-align: left; text-indent: 0px; background-color: #87CEEB; margin: 0px;">'
    echo '<span style="font-family: Calibri, sans-serif; font-size: 16pt; color: rgb(36, 36, 36);">&nbsp;</span></p>'
    echo "$i: $output"
  fi
done

