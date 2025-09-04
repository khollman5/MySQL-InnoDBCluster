#!/bin/bash
# Usage: ./netcheck.sh YYYY-MM-DD HH:MM
# Example: ./netcheck.sh 2025-08-19 05:10

if [ $# -ne 2 ]; then
    echo "Usage: $0 <YYYY-MM-DD> <HH:MM>"
    exit 1
fi

DATE="$1"
TIME="$2"

START="${DATE} ${TIME}:00"
END=$(date -d "$DATE $TIME:00 2 minutes" +"%Y-%m-%d %H:%M:%S")

echo "=== Checking logs between $START and $END ==="

echo
echo "### 1. System journal (network-related events)"
journalctl --since "$START" --until "$END" \
    | egrep -i "network|net|eth|ens|eno|link|firewall|drop|packet|nm-" || echo "No matches."

echo
echo "### 2. Kernel ring buffer (dmesg)"
dmesg --ctime | grep -iE "eth|ens|eno|link|drop|reset" \
    | grep "$(date -d "$START" +"%b %e %H:%M")" || echo "No matches."

echo
echo "### 3. NetworkManager logs"
journalctl -u NetworkManager --since "$START" --until "$END" || echo "No logs."

echo
echo "### 4. Firewalld logs"
journalctl -u firewalld --since "$START" --until "$END" || echo "No logs."

echo
echo "### 5. MySQL error log"
MYSQL_LOG=""
if [ -f /var/log/mysqld.log ]; then
    MYSQL_LOG="/var/log/mysqld.log"
elif [ -f /var/log/mysql/error.log ]; then
    MYSQL_LOG="/var/log/mysql/error.log"
fi

if [ -n "$MYSQL_LOG" ]; then
    # Match exact minute in ISO8601 UTC format, e.g. 2025-08-18T23:06:xx.xxxxxxZ
    grep -E "^${DATE}T${TIME}:[0-9]{2}\.[0-9]+Z" "$MYSQL_LOG" || echo "No matches."
else
    echo "MySQL log file not found."
fi


echo
echo "### 6. NIC error counters"
for iface in $(ls /sys/class/net | grep -v lo); do
    echo "--- Interface: $iface ---"
    ethtool -S $iface 2>/dev/null | egrep "err|drop|timeout" || echo "No counters available."
done
