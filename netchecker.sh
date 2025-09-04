#!/bin/bash
# netchecker.sh

host="$1"
shift

# Handle datetime (quoted or split in two)
if [ "$#" -eq 1 ]; then
    datetime="$1"
elif [ "$#" -eq 2 ]; then
    datetime="$1 $2"
else
    echo "Usage: $0 <host> <YYYY-MM-DD HH:MM>"
    exit 1
fi

# Extract up to and including the 2nd hyphen, e.g., "dbgsc-r-"
pattern=$(echo "$host" | awk -F'-' '{print $1 "-" $2 "-"}')
echo ">>> Extracted pattern: $pattern"

# Get matching hosts
echo ">>> Searching mysql_hosts.txt..."
hosts=$(grep -vE 'rtdb|web' mysql_hosts.txt | grep "$pattern")

if [ -z "$hosts" ]; then
    echo "No matching hosts found for pattern $pattern"
    exit 1
fi

echo ">>> Hosts found:"
echo "$hosts"

# Run command on each host
for i in $hosts; do
    echo ">>> Running on $i"
    ssh -q "$i" "echo $i && /root/MySQL/netcheck.sh $datetime"
done

