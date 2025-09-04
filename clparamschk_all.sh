#!/bin/bash

# --- CONFIG ---
LOGIN_PATH="icadmin"
REPLICA1="BI-instance-04"
REPLICA2="Analytics-instance-04"

# --- SQL PARAMS ---
SQL="SELECT variable_name, variable_value
FROM performance_schema.global_variables
ORDER BY variable_name;"

echo ""
echo "=== Current time: $(date) ==="
echo ""

# --- DETERMINE HOSTS ---
if [[ "$(hostname -s)" == "$REPLICA1" || "$(hostname -s)" == "$REPLICA2" ]]; then
    HOSTS=($(mysql --login-path=$LOGIN_PATH -h$(hostname -s) -N -e \
        "SELECT MEMBER_HOST
         FROM performance_schema.replication_group_members
         WHERE MEMBER_HOST IN ('$REPLICA1','$REPLICA2');"))
else
    HOSTS=($(mysql --login-path=$LOGIN_PATH -h$(hostname -s) -N -e \
        "SELECT MEMBER_HOST
         FROM performance_schema.replication_group_members
         ORDER BY MEMBER_HOST;"))
fi

echo "Cluster members: ${HOSTS[@]}"
echo ""

# --- GET VARIABLE NAMES FROM FIRST HOST ---
FIRST_HOST=${HOSTS[0]}
mapfile -t VARIABLES < <(mysql --login-path=$LOGIN_PATH -h$FIRST_HOST -N -e \
    "SELECT variable_name
     FROM performance_schema.global_variables
     ORDER BY variable_name;")

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
    VALUES=()
    for HOST in "${HOSTS[@]}"; do
        VALUE=$(mysql --login-path=$LOGIN_PATH -h$HOST -N -e \
            "SELECT variable_value
             FROM performance_schema.global_variables
             WHERE variable_name='$VAR';")
        VALUES+=("$VALUE")
    done

    # Check uniqueness
    UNIQUE=($(printf "%s\n" "${VALUES[@]}" | sort -u))

    if [[ ${#UNIQUE[@]} -gt 1 ]]; then
        # Only print if values differ
        printf "%-40s" "$VAR"
        for VALUE in "${VALUES[@]}"; do
            printf "\033[1;31m%-30s\033[0m" "$VALUE"
        done
        echo
    fi
done

