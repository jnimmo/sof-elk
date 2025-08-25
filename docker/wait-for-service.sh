#!/bin/bash
# wait-for-service.sh - Wait for a network service to become available

set -e

host="$1"
port="$2"
timeout="${3:-60}"

if [ -z "$host" ] || [ -z "$port" ]; then
    echo "Usage: $0 host port [timeout]"
    exit 1
fi

echo "Waiting for $host:$port to become available (timeout: ${timeout}s)..."

for i in $(seq 1 "$timeout"); do
    if nc -z "$host" "$port" 2>/dev/null; then
        echo "$host:$port is available!"
        exit 0
    fi
    sleep 1
done

echo "Timeout waiting for $host:$port"
exit 1