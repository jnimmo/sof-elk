#!/bin/bash
# SOF-ELK initialization script for Docker
set -e

log() {
    echo -e "\033[0;32m[SOF-ELK INIT]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[SOF-ELK INIT ERROR]\033[0m $1"
}

# Wait for Elasticsearch to be ready
wait_for_elasticsearch() {
    log "Waiting for Elasticsearch to be ready..."
    for i in {1..60}; do
        if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
            log "Elasticsearch is ready!"
            return 0
        fi
        sleep 2
    done
    error "Elasticsearch failed to start"
    exit 1
}

# Install Elasticsearch index templates
install_templates() {
    log "Installing Elasticsearch index templates..."
    
    # Component templates
    if [ -d "/usr/share/elasticsearch/templates/component_templates" ]; then
        for template in /usr/share/elasticsearch/templates/component_templates/*.json; do
            if [ -f "$template" ]; then
                template_name=$(basename "$template" .json)
                log "Installing component template: $template_name"
                curl -X PUT "localhost:9200/_component_template/$template_name" \
                     -H 'Content-Type: application/json' \
                     -d "@$template" || log "Warning: Failed to install component template $template_name"
            fi
        done
    fi
    
    # Index templates
    if [ -d "/usr/share/elasticsearch/templates/index_templates" ]; then
        for template in /usr/share/elasticsearch/templates/index_templates/*.json; do
            if [ -f "$template" ]; then
                template_name=$(basename "$template" .json)
                # Skip example templates
                if [[ "$template_name" == *"example"* ]]; then
                    continue
                fi
                log "Installing index template: $template_name"
                curl -X PUT "localhost:9200/_index_template/$template_name" \
                     -H 'Content-Type: application/json' \
                     -d "@$template" || log "Warning: Failed to install index template $template_name"
            fi
        done
    fi
}

# Wait for Kibana to be ready
wait_for_kibana() {
    log "Waiting for Kibana to be ready..."
    for i in {1..60}; do
        if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
            log "Kibana is ready!"
            return 0
        fi
        sleep 2
    done
    error "Kibana failed to start"
    exit 1
}

# Import Kibana saved objects
import_kibana_objects() {
    log "Importing Kibana saved objects..."
    
    # Data views (index patterns)
    if [ -d "/etc/kibana/sof-elk/data_views" ]; then
        for config in /etc/kibana/sof-elk/data_views/*.json; do
            if [ -f "$config" ]; then
                config_name=$(basename "$config" .json)
                log "Importing data view: $config_name"
                curl -X POST "localhost:5601/api/saved_objects/_import" \
                     -H "kbn-xsrf: true" \
                     -H "Content-Type: application/json" \
                     --form file="@$config" || log "Warning: Failed to import data view $config_name"
            fi
        done
    fi
    
    # Visualizations
    if [ -d "/etc/kibana/sof-elk/visualization" ]; then
        for config in /etc/kibana/sof-elk/visualization/*.json; do
            if [ -f "$config" ]; then
                config_name=$(basename "$config" .json)
                log "Importing visualization: $config_name"
                curl -X POST "localhost:5601/api/saved_objects/_import" \
                     -H "kbn-xsrf: true" \
                     -H "Content-Type: application/json" \
                     --form file="@$config" || log "Warning: Failed to import visualization $config_name"
            fi
        done
    fi
    
    # Dashboards
    if [ -d "/etc/kibana/sof-elk/dashboard" ]; then
        for config in /etc/kibana/sof-elk/dashboard/*.json; do
            if [ -f "$config" ]; then
                config_name=$(basename "$config" .json)
                log "Importing dashboard: $config_name"
                curl -X POST "localhost:5601/api/saved_objects/_import" \
                     -H "kbn-xsrf: true" \
                     -H "Content-Type: application/json" \
                     --form file="@$config" || log "Warning: Failed to import dashboard $config_name"
            fi
        done
    fi
    
    # Searches
    if [ -d "/etc/kibana/sof-elk/search" ]; then
        for config in /etc/kibana/sof-elk/search/*.json; do
            if [ -f "$config" ]; then
                config_name=$(basename "$config" .json)
                log "Importing search: $config_name"
                curl -X POST "localhost:5601/api/saved_objects/_import" \
                     -H "kbn-xsrf: true" \
                     -H "Content-Type: application/json" \
                     --form file="@$config" || log "Warning: Failed to import search $config_name"
            fi
        done
    fi
}

# Main initialization
main() {
    log "Starting SOF-ELK initialization..."
    
    wait_for_elasticsearch
    install_templates
    
    wait_for_kibana
    sleep 10  # Give Kibana additional time to fully initialize
    import_kibana_objects
    
    log "SOF-ELK initialization completed successfully!"
}

# Run main function
main