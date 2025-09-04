#!/bin/bash

# Usage: ./cluster_check_email.sh

DIR=/mnt/backup/scripts
MYSQLUSER=icadmin
REPLICA1="sage-p-db-04"
REPLICA2="opsdt-p-db-04"

echo ""
echo ""
echo "Current time:" `date`
MYSQLSH="mysqlsh --login-path=${MYSQLUSER} -h$(hostname -s) --tabbed -A --sqlc -e "
MYROUTER1=`${MYSQLSH} "select min(address) from mysql_innodb_cluster_metadata.routers" | grep -v address`
MYROUTER2=`${MYSQLSH} "select max(address) from mysql_innodb_cluster_metadata.routers" | grep -v address`

if [[ "$(hostname -s)" == "${REPLICA1}" || "$(hostname -s)" == "${REPLICA2}" ]]; then
  HOST=`${MYSQLSH} "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_HOST IN ('sage-p-db-04','opsdt-p-db-04')" | grep -v MEMBER`
 else
  HOST1=`${MYSQLSH} "select min(MEMBER_HOST) from performance_schema.replication_group_members " | grep -v MEMBER`
  HOST3=`${MYSQLSH} "select max(MEMBER_HOST) from performance_schema.replication_group_members " | grep -v MEMBER`
  HOST2=`${MYSQLSH} "select MEMBER_HOST from performance_schema.replication_group_members where MEMBER_HOST not in ('${HOST1}','${HOST3}')" | grep -v MEMBER`
fi

MYSQL="mysql --login-path=${MYSQLUSER} -h$(hostname -s) --html --table -A -e "

echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
echo '<span style="font-family: Calibri, sans-serif; font-size: 11pt; color: rgb(211, 211, 211);">&nbsp;</span></p>'
echo "Cluster Status"
if [[ "$(hostname -s)" == "${REPLICA2}" ]]; then
   ${MYSQL} "select rcs.CHANNEL_NAME, rcc.HOST as 'Src Primary', rcs.SERVICE_STATE as 'State', rcs.LAST_HEARTBEAT_TIMESTAMP from performance_schema.replication_connection_status rcs, performance_schema.replication_connection_configuration rcc where rcs.CHANNEL_NAME = rcc.CHANNEL_NAME and rcc.CHANNEL_NAME = 'read_replica_replication'"
 elif [[ "$(hostname -s)" == "${REPLICA1}" ]]; then
    # Command for REPLICA1
    mysqlsh --login-path=${MYSQLUSER} -h$(hostname -s) --js -e "var cs=dba.getClusterSet(); print(JSON.stringify(cs.status()));"
 else
   $MYSQL "select * from performance_schema.replication_group_members order by MEMBER_ROLE;"
fi

echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
echo '<span style="font-family: Calibri, sans-serif; font-size: 11pt; color: rgb(211, 211, 211);">&nbsp;</span></p>'
echo "Router status"
$MYSQL "select router_name, product_name , address, version, last_check_in from mysql_innodb_cluster_metadata.routers ;"

echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
echo '<span style="font-family: Calibri, sans-serif; font-size: 11pt; color: rgb(211, 211, 211);">&nbsp;</span></p>'
echo "Instance uptimes"
if [[ "$(hostname -s)" == "${REPLICA1}" || "$(hostname -s)" == "${REPLICA2}" ]]; then
  mysql --login-path=${MYSQLUSER} -h$(hostname -s) --table -A --html -e " source ${DIR}/uptime.sql"
 else
  mysql --login-path=${MYSQLUSER} -h${HOST1} --table -A --html -e " source ${DIR}/uptime.sql"
  mysql --login-path=${MYSQLUSER} -h${HOST2} --table -A --html -e " source ${DIR}/uptime.sql" 
  mysql --login-path=${MYSQLUSER} -h${HOST3} --table -A --html -e " source ${DIR}/uptime.sql"
fi

echo '<p style="text-align: left; text-indent: 0px; background-color: white; margin: 0px;">'
echo '<span style="font-family: Calibri, sans-serif; font-size: 11pt; color: rgb(211, 211, 211);">&nbsp;</span></p>'
echo "Error Log"
$MYSQL "select LOGGED as Last, ERROR_CODE, SUBSYSTEM, DATA from performance_schema.error_log order by 1 desc limit 3"

