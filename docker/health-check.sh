#!/bin/bash
# health-check.sh - Health check script for SOF-ELK services

set -e

SERVICE=${1:-"all"}

check_elasticsearch() {
    curl -f -s http://localhost:9200/_cluster/health >/dev/null
}

check_logstash() {
    curl -f -s http://localhost:9600 >/dev/null
}

check_kibana() {
    curl -f -s http://localhost:5601/api/status >/dev/null
}

case "$SERVICE" in
    "elasticsearch")
        check_elasticsearch
        ;;
    "logstash")
        check_logstash
        ;;
    "kibana")
        check_kibana
        ;;
    "all")
        check_elasticsearch && check_logstash && check_kibana
        ;;
    *)
        echo "Usage: $0 [elasticsearch|logstash|kibana|all]"
        exit 1
        ;;
esac

echo "$SERVICE is healthy"