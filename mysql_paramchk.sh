#!/bin/bash

# Define replicas for special case
REPLICA1="sage-p-db-04"
REPLICA2="opsdt-p-db-04"

MYSQLUSER="icadmin"
MYSQLSH="mysqlsh --login-path=${MYSQLUSER} -h$(hostname -s) --sqlc -N -e"

# Parameter list
PARAMS="'innodb_buffer_pool_size','innodb_redo_log_capacity','binlog_expire_logs_seconds',
'innodb_log_buffer_size','innodb_buffer_pool_instances','innodb_flush_neighbors','max_connections',
'max_connect_errors','wait_timeout','interactive_timeout','table_open_cache','open_files_limit',
'tmp_table_size','max_heap_table_size','sort_buffer_size','join_buffer_size','read_buffer_size',
'read_rnd_buffer_size','slow_query_log','log_output','local_infile','skip_name_resolve','binlog_row_image',
'innodb_spin_wait_delay','group_replication_autorejoin_tries','group_replication_member_weight',
'innodb_flushing_avg_loops','innodb_idle_flush_pct','innodb_io_capacity','innodb_lru_scan_depth',
'autocommit','innodb_flush_log_at_trx_commit','log_error_suppression_list','unique_checks',
'group_replication_transaction_size_limit','bulk_insert_buffer_size'"

SQL="SELECT variable_name, variable_value 
FROM performance_schema.global_variables 
WHERE variable_name IN ($PARAMS) ORDER BY variable_name;"

echo ""
echo "=== Current time: $(date) ==="
echo ""

# Get list of cluster members
if [[ "$(hostname -s)" == "$REPLICA1" || "$(hostname -s)" == "$REPLICA2" ]]; then
    HOSTS=$(${MYSQLSH} "SELECT MEMBER_HOST 
                        FROM performance_schema.replication_group_members 
                        WHERE MEMBER_HOST IN ('$REPLICA1','$REPLICA2');")
else
    HOSTS=$(${MYSQLSH} "SELECT MEMBER_HOST 
                        FROM performance_schema.replication_group_members 
                        ORDER BY MEMBER_HOST;")
fi

# Build pivot: first fetch variable names from the first host
FIRST_HOST=$(echo "$HOSTS" | head -n1)

mapfile -t VARIABLES < <(mysqlsh --login-path=$MYSQLUSER -h$FIRST_HOST --sqlc -N -e \
    "SELECT variable_name FROM performance_schema.global_variables 
     WHERE variable_name IN ($PARAMS) ORDER BY variable_name;")

# Print header
echo -e "variable_name\t$(echo "$HOSTS" | tr '\n' '\t')"

# Collect values
for VAR in "${VARIABLES[@]}"; do
    LINE="$VAR"
    for HOST in $HOSTS; do
        VALUE=$(mysqlsh --login-path=$MYSQLUSER -h$HOST --sqlc -N -e \
            "SELECT variable_value FROM performance_schema.global_variables WHERE variable_name='$VAR';")
        LINE+="\t$VALUE"
    done
    echo -e "$LINE"
done

