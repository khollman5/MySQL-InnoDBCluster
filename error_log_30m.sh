#!/bin/bash

MYSQLUSER=icadmin
  for MEMBER in `mysqlsh \-\-login-path=${MYSQLUSER} -h"$(hostname -s)" --sqlc -e "select member_host from performance_schema.replication_group_members order by 1" | grep -i '\-db\-'`
    do
     output=$(mysql \-\-login-path=${MYSQLUSER} -h${MEMBER} --html --table -A -e \
      "select LOGGED as Last, ERROR_CODE, SUBSYSTEM, DATA from performance_schema.error_log where logged > (NOW() - INTERVAL 30 MINUTE)")

      if [[ -n "$output" ]]; then
         echo '<p style="text-align: left; text-indent: 0px; background-color: #87CEEB; margin: 0px;">'
         echo '<span style="font-family: Calibri, sans-serif; font-size: 16pt; color: rgb(36, 36, 36);">&nbsp;<b>'
         echo "$MEMBER"
         echo '</b></span></p>'
         echo '<span style="font-family: Calibri, sans-serif; font-size: 9pt; color: rgb(36, 36, 36);">&nbsp;'
         echo "$output"
         echo '</b></span></p>'
      fi
   done

