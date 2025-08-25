#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[SOF-ELK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[SOF-ELK WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[SOF-ELK ERROR]${NC} $1"
}

# Function to wait for a service
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local timeout=${4:-60}
    
    log "Waiting for $service to be ready at $host:$port..."
    
    for i in $(seq 1 $timeout); do
        if nc -z $host $port 2>/dev/null; then
            log "$service is ready!"
            return 0
        fi
        sleep 1
    done
    
    error "$service failed to start within $timeout seconds"
    return 1
}

# Function to start Elasticsearch
start_elasticsearch() {
    log "Starting Elasticsearch..."
    
    # Create necessary directories
    mkdir -p /var/lib/elasticsearch /var/log/elasticsearch /var/run/elasticsearch
    chown -R elasticsearch:elasticsearch /var/lib/elasticsearch /var/log/elasticsearch /var/run/elasticsearch
    
    # Set JVM heap size based on available memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print int($2/2)}')
    if [ $MEMORY_GB -lt 1 ]; then
        MEMORY_GB=1
    fi
    export ES_JAVA_OPTS="-Xms${MEMORY_GB}g -Xmx${MEMORY_GB}g"
    
    # Start Elasticsearch as elasticsearch user
    sudo -u elasticsearch -E /usr/share/elasticsearch/bin/elasticsearch \
        -p /var/run/elasticsearch/elasticsearch.pid \
        -d
    
    wait_for_service localhost 9200 "Elasticsearch"
}

# Function to start Logstash
start_logstash() {
    log "Starting Logstash..."
    
    # Create necessary directories
    mkdir -p /var/lib/logstash /var/log/logstash /var/run/logstash
    chown -R logstash:logstash /var/lib/logstash /var/log/logstash /var/run/logstash
    
    # Set JVM heap size
    export LS_JAVA_OPTS="-Xms1g -Xmx1g"
    
    # Start Logstash as logstash user
    sudo -u logstash -E /usr/share/logstash/bin/logstash \
        --path.settings=/etc/logstash \
        --log.level=info &
    
    echo $! > /var/run/logstash/logstash.pid
    
    wait_for_service localhost 9600 "Logstash"
}

# Function to start Kibana
start_kibana() {
    log "Starting Kibana..."
    
    # Create necessary directories
    mkdir -p /var/log/kibana /var/run/kibana
    chown -R kibana:kibana /var/log/kibana /var/run/kibana
    
    # Start Kibana as kibana user
    sudo -u kibana -E /usr/share/kibana/bin/kibana \
        --config /etc/kibana/kibana.yml &
    
    echo $! > /var/run/kibana/kibana.pid
    
    wait_for_service localhost 5601 "Kibana"
}

# Function to initialize SOF-ELK
initialize_sof_elk() {
    log "Initializing SOF-ELK configurations..."
    
    # Wait for Elasticsearch to be fully ready
    sleep 10
    
    # Install Elasticsearch templates
    if [ -d "/usr/share/elasticsearch/templates" ]; then
        log "Installing Elasticsearch index templates..."
        for template_dir in /usr/share/elasticsearch/templates/*/; do
            if [ -d "$template_dir" ]; then
                for template in "$template_dir"*.json; do
                    if [ -f "$template" ]; then
                        template_name=$(basename "$template" .json)
                        log "Installing template: $template_name"
                        curl -X PUT "localhost:9200/_template/$template_name" \
                             -H 'Content-Type: application/json' \
                             -d "@$template" || warn "Failed to install template $template_name"
                    fi
                done
            fi
        done
    fi
    
    # Load Kibana dashboards and configurations
    if [ -d "/etc/kibana/sof-elk" ]; then
        log "Loading Kibana dashboards and visualizations..."
        sleep 5  # Give Kibana more time to start
        
        # Import saved objects
        for config_dir in /etc/kibana/sof-elk/*/; do
            if [ -d "$config_dir" ]; then
                config_type=$(basename "$config_dir")
                log "Loading $config_type configurations..."
                
                for config_file in "$config_dir"*.json; do
                    if [ -f "$config_file" ]; then
                        config_name=$(basename "$config_file" .json)
                        curl -X POST "localhost:5601/api/saved_objects/_import" \
                             -H "kbn-xsrf: true" \
                             -H "Content-Type: application/json" \
                             --form file="@$config_file" || warn "Failed to load $config_name"
                    fi
                done
            fi
        done
    fi
    
    log "SOF-ELK initialization completed!"
}

# Function to show status
show_status() {
    log "SOF-ELK Status:"
    echo "----------------------------------------"
    
    if nc -z localhost 9200 2>/dev/null; then
        echo -e "Elasticsearch: ${GREEN}Running${NC} (http://localhost:9200)"
    else
        echo -e "Elasticsearch: ${RED}Stopped${NC}"
    fi
    
    if nc -z localhost 9600 2>/dev/null; then
        echo -e "Logstash: ${GREEN}Running${NC} (http://localhost:9600)"
    else
        echo -e "Logstash: ${RED}Stopped${NC}"
    fi
    
    if nc -z localhost 5601 2>/dev/null; then
        echo -e "Kibana: ${GREEN}Running${NC} (http://localhost:5601)"
    else
        echo -e "Kibana: ${RED}Stopped${NC}"
    fi
    
    echo "----------------------------------------"
}

# Handle different commands
case "${1:-all}" in
    "elasticsearch")
        start_elasticsearch
        ;;
    "logstash")
        start_logstash
        ;;
    "kibana")
        start_kibana
        ;;
    "all")
        log "Starting SOF-ELK stack..."
        start_elasticsearch
        start_logstash
        start_kibana
        initialize_sof_elk
        show_status
        log "SOF-ELK is ready!"
        ;;
    "init")
        initialize_sof_elk
        ;;
    "status")
        show_status
        exit 0
        ;;
    *)
        error "Unknown command: $1"
        echo "Usage: $0 [elasticsearch|logstash|kibana|all|init|status]"
        exit 1
        ;;
esac

# Keep container running
if [ "${1:-all}" = "all" ]; then
    log "SOF-ELK is running. Press Ctrl+C to stop."
    trap 'log "Shutting down SOF-ELK..."; kill $(jobs -p); exit 0' SIGTERM SIGINT
    
    # Monitor services and restart if needed
    while true; do
        sleep 30
        
        # Check if services are still running
        if ! nc -z localhost 9200 2>/dev/null; then
            warn "Elasticsearch appears to be down, restarting..."
            start_elasticsearch
        fi
        
        if ! nc -z localhost 9600 2>/dev/null; then
            warn "Logstash appears to be down, restarting..."
            start_logstash
        fi
        
        if ! nc -z localhost 5601 2>/dev/null; then
            warn "Kibana appears to be down, restarting..."
            start_kibana
        fi
    done
else
    # For single service mode, just wait
    wait
fi