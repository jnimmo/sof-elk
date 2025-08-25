#!/bin/sh
set -e

echo "Starting SOF-ELK initialization..."

# Install required tools
echo "Installing required tools..."
apk add --no-cache curl jq

# Create data directories structure
echo "Setting up data directories..."
mkdir -p /data/zeek-logs
mkdir -p /data/netflow
mkdir -p /data/sysmon
mkdir -p /data/apache
mkdir -p /data/nginx
mkdir -p /data/iis
mkdir -p /data/suricata
mkdir -p /data/snort
mkdir -p /data/cloudtrail
mkdir -p /data/azure
mkdir -p /data/gcp
mkdir -p /data/plaso
mkdir -p /data/kape
mkdir -p /data/hayabusa
mkdir -p /data/custom
mkdir -p /data/windows-events
mkdir -p /data/syslog
mkdir -p /data/dhcp
mkdir -p /data/dns
mkdir -p /data/ssh
mkdir -p /data/firewall
mkdir -p /data/forensics

# Create README file with directory explanations
cat > /data/README.md << 'EOF'
# SOF-ELK Data Directory Structure

This directory contains subdirectories for different types of log data that SOF-ELK can automatically process.

## Directory Structure:

- **zeek-logs/**: Zeek/Bro network analysis logs (.log files)
- **netflow/**: NetFlow data files
- **sysmon/**: Windows Sysmon logs
- **apache/**: Apache web server logs
- **nginx/**: Nginx web server logs  
- **iis/**: Microsoft IIS web server logs
- **suricata/**: Suricata IDS logs
- **snort/**: Snort IDS logs
- **cloudtrail/**: AWS CloudTrail logs
- **azure/**: Azure cloud logs
- **gcp/**: Google Cloud Platform logs
- **plaso/**: Plaso timeline data
- **kape/**: KAPE forensic artifacts
- **hayabusa/**: Hayabusa Windows event analysis results
- **windows-events/**: Windows Event logs (.evtx files)
- **syslog/**: System logs
- **dhcp/**: DHCP server logs
- **dns/**: DNS server logs
- **ssh/**: SSH server logs
- **firewall/**: Firewall logs
- **forensics/**: General forensic artifacts
- **custom/**: Custom log formats

## Usage:

1. Place your log files in the appropriate subdirectory
2. SOF-ELK will automatically detect and process supported formats
3. View processed data in Kibana at http://localhost:5601

## File Formats Supported:

- .log files (various formats)
- .evtx (Windows Event logs)
- .json (structured logs)
- .csv (comma-separated values)
- .txt (text logs)

Files are monitored recursively, so you can create additional subdirectories as needed.
EOF

# Set proper permissions (only on subdirectories, not the mount point)
find /data -type d -exec chmod 755 {} \; 2>/dev/null || true
find /data -name "README.md" -exec chmod 644 {} \; 2>/dev/null || true
echo "Data directories created successfully!"
echo "See /data/README.md for usage information."

# Wait for Elasticsearch to be fully ready
echo "Waiting for Elasticsearch..."
until curl -s http://elasticsearch:9200/_cluster/health | grep -q '"status":"green\|yellow"'; do
  echo "Waiting for Elasticsearch to be healthy..."
  sleep 5
done
echo "Elasticsearch is ready!"

# Wait for Kibana to be ready
echo "Waiting for Kibana..."
until curl -s http://kibana:5601/api/status | grep -q '"level":"available"'; do
  echo "Waiting for Kibana to be ready..."
  sleep 5
done
echo "Kibana is ready!"

# Install Elasticsearch component templates
if [ -d "/templates/component_templates" ]; then
    echo "Installing Elasticsearch component templates..."
    for template in /templates/component_templates/*.json; do
        if [ -f "$template" ]; then
            template_name=$(basename "$template" .json)
            echo "Installing component template: $template_name"
            curl -X PUT "elasticsearch:9200/_component_template/$template_name" \
                 -H 'Content-Type: application/json' \
                 -d "@$template" || echo "Warning: Failed to install component template $template_name"
        fi
    done
fi

# Install Elasticsearch index templates
if [ -d "/templates/index_templates" ]; then
    echo "Installing Elasticsearch index templates..."
    for template in /templates/index_templates/*.json; do
        if [ -f "$template" ]; then
            template_name=$(basename "$template" .json)
            # Skip example templates
            case "$template_name" in
                *example*) continue ;;
            esac
            echo "Installing index template: $template_name"
            curl -X PUT "elasticsearch:9200/_index_template/$template_name" \
                 -H 'Content-Type: application/json' \
                 -d "@$template" || echo "Warning: Failed to install index template $template_name"
        fi
    done
fi

# Import Kibana saved objects
echo "Importing Kibana configurations..."
sleep 5  # Give Kibana more time

# Import data views first (they're required for dashboards)
if [ -d "/kibana-configs/data_views" ]; then
    echo "Importing Kibana data views..."
    for dataviewfile in /kibana-configs/data_views/*.json; do
        if [ -f "$dataviewfile" ]; then
            DATAVIEWID=$(basename "$dataviewfile" .json)
            echo "Loading Data View: $DATAVIEWID"
            # Delete existing data view first, then create new one
            curl -s -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
                 -X DELETE "http://kibana:5601/api/data_views/data_view/$DATAVIEWID" > /dev/null 2>&1
            curl -s -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
                 -X POST "http://kibana:5601/api/data_views/data_view" \
                 -d "@$dataviewfile" > /dev/null || echo "Warning: Failed to import data view $DATAVIEWID"
        fi
    done
fi

# Import dashboards, visualizations, maps, and searches using bulk import
# Create temporary NDJSON file for bulk import
TMPNDJSONFILE=/tmp/kibana_objects.ndjson
rm -f $TMPNDJSONFILE

echo "Preparing Kibana objects for bulk import..."
# ORDER MATTERS! Dependencies in the "references" field require objects to be present
for objecttype in visualization lens map search dashboard; do
    if [ -d "/kibana-configs/$objecttype" ]; then
        echo "Adding $objecttype objects..."
        for objectfile in /kibana-configs/$objecttype/*.json; do
            if [ -f "$objectfile" ]; then
                # Convert each JSON file to compact JSON and append to NDJSON
                jq -c '.' "$objectfile" >> $TMPNDJSONFILE 2>/dev/null
            fi
        done
    fi
done

# Import all objects in bulk if we have any
if [ -f "$TMPNDJSONFILE" ] && [ -s "$TMPNDJSONFILE" ]; then
    echo "Loading Kibana objects in bulk..."
    curl -s -H 'kbn-xsrf: true' \
         --form file=@$TMPNDJSONFILE \
         -X POST "http://kibana:5601/api/saved_objects/_import?overwrite=true" > /dev/null \
         && echo "Successfully imported Kibana objects" \
         || echo "Warning: Some Kibana objects may have failed to import"
    rm -f $TMPNDJSONFILE
else
    echo "No Kibana objects found to import"
fi

echo "SOF-ELK initialization completed successfully!"
echo "Access Kibana at: http://localhost:5601"
echo "Access Elasticsearch at: http://localhost:9200"