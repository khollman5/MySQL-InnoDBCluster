#!/bin/bash

# --- CONFIG ---
LOGIN_PATH="icadmin"
REPLICA1="BI-instance-04"
REPLICA2="analytics-instance-04"

# --- SQL PARAMS ---
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

# --- DETERMINE HOSTS ---
if [[ "$(hostname -s)" == "$REPLICA1" ]]; then
    HOSTS=($(mysql --login-path=$LOGIN_PATH -h$(hostname -s) -N -e \
        "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_HOST = '$REPLICA1';"))
 elif [[ "$(hostname -s)" == "${REPLICA2}" ]]; then
    HOSTS=(${REPLICA2})
 else
    HOSTS=($(mysql --login-path=$LOGIN_PATH -h$(hostname -s) -N -e \
        "SELECT MEMBER_HOST FROM performance_schema.replication_group_members ORDER BY MEMBER_HOST;"))
fi

echo "Cluster members: ${HOSTS[@]}"
echo ""

# --- GET VARIABLE NAMES FROM FIRST HOST ---
FIRST_HOST=${HOSTS[0]}
mapfile -t VARIABLES < <(mysql --login-path=$LOGIN_PATH -h$FIRST_HOST -N -e \
    "SELECT variable_name 
     FROM performance_schema.global_variables 
     WHERE variable_name IN ($PARAMS) ORDER BY variable_name;")

# --- PRINT HEADER ---
printf "%-40s" "variable_name"
for HOST in "${HOSTS[@]}"; do
    printf "%-30s" "$HOST"
done
echo
printf '=%.0s' {1..200}
echo

# --- FETCH VALUES ---
for VAR in "${VARIABLES[@]}"; do
    printf "%-40s" "$VAR"

    # Collect values for this variable across hosts
    VALUES=()
    for HOST in "${HOSTS[@]}"; do
        VALUE=$(mysql --login-path=$LOGIN_PATH -h$HOST -N -e \
            "SELECT variable_value
             FROM performance_schema.global_variables
             WHERE variable_name='$VAR';")
        VALUES+=("$VALUE")
    done

    # Find if all values are the same
    UNIQUE=($(printf "%s\n" "${VALUES[@]}" | sort -u))

    for VALUE in "${VALUES[@]}"; do
        if [[ ${#UNIQUE[@]} -gt 1 ]]; then
            # Different values → highlight differences
            printf "\033[1;31m%-30s\033[0m" "$VALUE"
        else
            # All values same → normal print
            printf "%-30s" "$VALUE"
        fi
    done
    echo
done

