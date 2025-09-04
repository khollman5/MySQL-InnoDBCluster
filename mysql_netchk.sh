#!/bin/bash
# network_monitor.sh
# Usage: ./network_monitor.sh node1 node2 ... -o output.log
# Example: ./network_monitor.sh sage-p-db-01 sage-p-db-02 sage-p-db-03 -o /tmp/net_monitor.log

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 node1 node2 ... -o output.log"
    exit 1
fi

# Extract output file
while [[ $# -gt 0 ]]; do
    case $1 in
        -o)
            shift
            OUTPUT_FILE="$1"
            shift
            ;;
        *)
            NODES+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$OUTPUT_FILE" ]]; then
    echo "Output file not specified."
    exit 1
fi

echo "Logging to $OUTPUT_FILE"
echo "Timestamp,Source,Target,Ping_ms,PacketLoss,TCP_Retrans" > "$OUTPUT_FILE"

# Infinite loop (can Ctrl+C to stop)
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    for SRC in "${NODES[@]}"; do
        for DST in "${NODES[@]}"; do
            [[ "$SRC" == "$DST" ]] && continue

            # Ping test (5 packets)
            PING_OUTPUT=$(ping -c 5 -q "$DST" 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                LATENCY="NA"
                LOSS="100%"
            else
                LATENCY=$(echo "$PING_OUTPUT" | awk -F'/' '/rtt/ {print $5}')  # avg ms
                LOSS=$(echo "$PING_OUTPUT" | awk -F', ' '/packet loss/ {print $3}')
            fi

            # TCP retransmissions for the src host
            TCP_RETRANS=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "$SRC" "cat /proc/net/snmp | awk '/Tcp:/ {if(NR==4) print \$12}'" 2>/dev/null)
            [[ -z "$TCP_RETRANS" ]] && TCP_RETRANS="NA"

            echo "$TIMESTAMP,$SRC,$DST,$LATENCY,$LOSS,$TCP_RETRANS" >> "$OUTPUT_FILE"
        done
    done

    # Sleep 30 seconds between checks
    sleep 30
done

