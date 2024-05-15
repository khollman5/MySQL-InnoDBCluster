#!/bin/bash

# Usage: ./obs_mysql_cluster.sh


# OUTPUTFILE="USER INPUT"
read -p "Enter the OUTPUTFILE being used:                      " OUTPUTFILE
# FILEDIR="USER INPUT"
read -p "Now enter the directory where $OUTPUTFILE resides: " FILEDIR
# MYROUTER1="USER INPUT"
read -p "Now provide the 1st MySQL Router hostname to be used:  " MYROUTER1
# MYROUTER2="USER INPUT"
read -p "Now provide the 2nd MySQL Router hostname to be used:  " MYROUTER2
# HOST1="USER INPUT"
read -p "Enter the 1st MySQL Cluster Node name:                 " HOST1
# HOST2="USER INPUT"
read -p "Enter the 2nd MySQL Cluster Node name:                 " HOST2
# HOST3="USER INPUT"
read -p "Enter the 3rd MySQL Cluster Node name:                 " HOST3
echo
echo "You have entered: "
echo "                  "$OUTPUTFILE
echo "                  "$FILEDIR
echo "                  "$MYROUTER1" & "$MYROUTER2
echo "                  "$HOST1" & "$HOST2" & "$HOST3
echo "                  "$HOSTNAME" is the current host."
echo
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1


#######################
# Monitoring a Cluster:

echo "Remember: login-path needs to be defined."
MYSQLLOGIN=icadmin
MYSQLSH='mysqlsh --login-path=$MYSQLLOGIN -h$MYROUTER1 --sqlc -e '

# General setup:

echo "Obtaining MySQL InnoDB Cluster basics:"
$MYSQLSH "select cluster_id, cluster_name, description, cluster_type, primary_mode, clusterset_id from mysql_innodb_cluster_metadata.clusters;"
echo "Members of our cluster:"
$MYSQLSH "select * from performance_schema.replication_group_members order by MEMBER_ROLE;"

echo "GR Applier & Recovery threads:"
$MYSQLSH "select CHANNEL_NAME, SERVICE_STATE, COUNT_RECEIVED_HEARTBEATS, RECEIVED_TRANSACTION_SET, LAST_ERROR_NUMBER, LAST_ERROR_MESSAGE, LAST_ERROR_TIMESTAMP, LAST_QUEUED_TRANSACTION, QUEUEING_TRANSACTION from performance_schema.replication_connection_status \G"

$MYSQLSH "select CHANNEL_NAME, WORKER_ID, THREAD_ID, SERVICE_STATE, LAST_ERROR_NUMBER, LAST_ERROR_MESSAGE, LAST_ERROR_TIMESTAMP, LAST_APPLIED_TRANSACTION, APPLYING_TRANSACTION, APPLYING_TRANSACTION_RETRIES_COUNT from performance_schema.replication_applier_status_by_worker order by CHANNEL_NAME,WORKER_ID,THREAD_ID ;"

echo "From o.s. command line:"
uname -a 
echo "Check all cluster members have the same topology understanding (if not, we will see split-brain topology):"
mysqlsh $MYSQLLOGIN@$MYROUTER1:3306 --sqlc --redirect-primary -e "select @@hostname,@@port;"
mysqlsh $MYSQLLOGIN@$MYROUTER2:3306 --sqlc --redirect-primary -e "select @@hostname,@@port;"
mysqlsh $MYSQLLOGIN@$HOST1:3306 --sqlc --redirect-primary -e "select @@hostname,@@port;"
mysqlsh $MYSQLLOGIN@$HOST2:3306 --sqlc --redirect-primary -e "select @@hostname,@@port;"
mysqlsh $MYSQLLOGIN@$HOST3:3306 --sqlc --redirect-primary -e "select @@hostname,@@port;"
echo "Now run each of the previous commands from the other 4 servers..:"


echo "MySQL Routers, according to the cluster:"
$MYSQLSH "select router_name, product_name , address, version, last_check_in from mysql_innodb_cluster_metadata.routers ;"

echo "MySQL Router state on each Router server:"
echo "ssh -q root@$MYROUTER1"
ps -ef | grep mysqlrouter
cat /var/lib/mysqlrouter/state.json

echo "ssh -q root@$MYROUTER2"
ps -ef | grep mysqlrouter
cat /var/lib/mysqlrouter/state.json

# Network testing
# Make sure these are run from all servers to all servers;
netstat -l | grep mysql
tracepath -b -p 3306 dbnode1

echo "Get the instances config:"
$MYSQLSH "select @@hostname,@@port, @@external_user, @@proxy_user,@@read_only, @@pid_file, @@pseudo_thread_id, @@socket, @@wait_timeout, @@init_connect, @@init_file, @@init_replica, @@innodb_status_output, @@net_retry_count \G"

echo "GR & Replica config / status:" 
$MYSQLSH "select @@group_replication_group_name, @@group_replication_local_address, @@group_replication_group_seeds, @@group_replication_communication_stack, @@group_replication_flow_control_mode, @@group_replication_flow_control_min_quota, @@group_replication_flow_control_max_quota, @@group_replication_communication_debug_options, @@group_replication_autorejoin_tries, @@replica_transaction_retries, @@replica_checkpoint_period, @@group_replication_exit_state_action, @@group_replication_flow_control_period, @@group_replication_unreachable_majority_timeout, @@replica_net_timeout, @@group_replication_transaction_size_limit, @@replica_max_allowed_packet, @@gtid_purged, @@gtid_executed, @@gtid_next, @@replica_exec_mode, @@replica_preserve_commit_order, @@replica_type_conversions, @@replication_sender_observe_commit_only \G"

echo "Connection thread memory consumption (BG vs FG):"
$MYSQLSH "select type,sum(TOTAL_MEMORY)/1048576 "Memory(Mb)" from performance_schema.threads group by type;"

echo "Count of connection types:"
$MYSQLSH "select name, connection_type, count(*) from performance_schema.threads where connection_type is not null group by name, connection_type order by 3 desc ;"

echo "Some connection statistics:"
$MYSQLSH "select VARIABLE_NAME, VARIABLE_VALUE from global_status where VARIABLE_NAME like 'connect%';"

echo "Group Replication thread memory usage:" 
$MYSQLSH "select name, type, sum(TOTAL_MEMORY)/1048576 "Memory(Mb)", count(*) from performance_schema.threads where name like 'thread/group_rpl%' group by name, type order by 3 desc ;"

echo "Global thread memory usage:" 
$MYSQLSH "select sum(TOTAL_MEMORY)/1048576 "Memory(Mb)", name, type, CONNECTION_TYPE from performance_schema.threads group by name, type, CONNECTION_TYPE order by 1 desc;"

echo "Bytes sent/received per user:"
$MYSQLSH "select user, VARIABLE_NAME, VARIABLE_VALUE/1048576 from performance_schema.status_by_user where VARIABLE_NAME in ('Bytes_received','Bytes_sent') order by 3 asc;"

echo "Naughty users:"
$MYSQLSH "select user, VARIABLE_NAME, VARIABLE_VALUE from performance_schema.status_by_user where VARIABLE_NAME in ('Select_full_join','Select_scan','Slow_queries','Max_execution_time_exceeded') and VARIABLE_VALUE > '0' order by 1,2;"
 
$MYSQLSH "WITH RECURSIVE ratios (user, Misses, Hits) as ( SELECT user, MAX(CASE WHEN variable_name='Table_open_cache_misses' THEN variable_value END) AS Misses, MAX(CASE WHEN variable_name='Table_open_cache_hits' THEN variable_value END) AS Hits FROM performance_schema.status_by_user where variable_value > 0 and variable_value is not null group by user) select user, Misses, Hits, round(ratios.Misses/ratios.Hits*100,2) as "Ratio%" from ratios order BY 4 asc;"

echo "The End!"

