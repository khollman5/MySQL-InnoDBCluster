#!/bin/bash

# Usage: ./mysql_status.sh

MYSQLSH='mysqlsh --login-path=icadmin -h${HOSTNAME} --sqlc -e '

# Leaving nodes 3 (5 for moodle) as hosts to be inspected:
for i in `cat mysql_hosts.txt | grep -Ev 'web|rtdb|02|03|06|07'`
do
 banner()
 {
   echo "+-------------------------------+"
 #  printf "| %-30s |\n" "`date`"
 #  echo "|                                |"
    printf "|        `tput bold` %-21s `tput sgr0`|\n" "$@"
   echo "+-------------------------------+"
 }
 
 banner "$i"
 ssh -q $i "/mnt/backup/scripts/cluster_check.sh"
 echo ""
 sleep 4
 echo ""
done

for i in `cat mysql_routers.txt`
do
  output=$(ssh -q "$i" "tail -15000 /root/MySQL/RouterStatus.log | grep -B 1 -i restarting" | tr '\n' ' ')
  if [[ -n "$output" ]]; then
    echo "$i: $output"
  fi
done

banner "The End."
echo ""
