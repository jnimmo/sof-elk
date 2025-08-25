# SOF-ELK Docker Deployment

This directory contains Docker configurations for running SOF-ELK (Security Operations and Forensics Elastic Stack) in containers instead of a virtual machine.

## Quick Start

### Single Container (All-in-One)
For development and testing:
```bash
docker-compose -f docker-compose.single.yml up -d
```

### Multi-Container (Production-like)
For better resource isolation:
```bash
docker-compose up -d
```

### Access URLs
- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **Logstash API**: http://localhost:9600

## Architecture

### Multi-Container Setup
- **elasticsearch**: Elasticsearch server with SOF-ELK index templates
- **logstash**: Logstash with SOF-ELK parsing configurations
- **kibana**: Kibana with SOF-ELK dashboards and visualizations
- **filebeat**: Optional log shipper for collecting logs

### Single Container Setup
All components run in a single container with automatic service management.

## Configuration

### Data Ingestion
Place your log files in the `./data` directory. The container will automatically process supported formats:

- Network logs (NetFlow, Zeek/Bro, etc.)
- System logs (Sysmon, Windows Event Logs, etc.)
- Web server logs (Apache, Nginx, IIS)
- Security logs (Suricata, Snort, etc.)
- Cloud logs (AWS CloudTrail, Azure, GCP)
- Digital forensics artifacts (Plaso, KAPE, Hayabusa)

### Custom Configurations
Place custom Logstash configurations in `./custom-configs/` directory:
```bash
mkdir -p custom-configs
# Add your .conf files here
```

### Memory Requirements
- **Minimum**: 4GB RAM (single container)
- **Recommended**: 8GB+ RAM (multi-container)
- **Production**: 16GB+ RAM

Adjust memory settings in docker-compose files:
```yaml
environment:
  - "ES_JAVA_OPTS=-Xms2g -Xmx2g"  # Elasticsearch heap
  - "LS_JAVA_OPTS=-Xms1g -Xmx1g"   # Logstash heap
```

## Usage Examples

### Processing Network Logs
```bash
# Place Zeek logs in data directory
cp /path/to/zeek-logs/*.log ./data/

# Start containers
docker-compose up -d

# Check processing status
docker-compose logs logstash
```

### Processing Windows Event Logs
```bash
# Place EVTX files in data directory
cp /path/to/logs/*.evtx ./data/

# View in Kibana
open http://localhost:5601
```

### Custom Parsing
```bash
# Create custom config
mkdir -p custom-configs
cat > custom-configs/9100-custom-app.conf << EOF
filter {
  if [fields][log_type] == "custom-app" {
    # Your custom parsing logic
  }
}
EOF

# Restart to apply changes
docker-compose restart logstash
```

## Management Commands

### Start Services
```bash
docker-compose up -d                    # Multi-container
docker-compose -f docker-compose.single.yml up -d  # Single container
```

### Stop Services
```bash
docker-compose down                     # Stop and remove containers
docker-compose down -v                  # Stop and remove containers + volumes
```

### View Logs
```bash
docker-compose logs -f elasticsearch   # Elasticsearch logs
docker-compose logs -f logstash        # Logstash logs
docker-compose logs -f kibana           # Kibana logs
```

### Scale Services
```bash
docker-compose up -d --scale logstash=2  # Run 2 Logstash instances
```

### Update Containers
```bash
docker-compose pull                     # Pull latest images
docker-compose up -d --force-recreate   # Recreate containers
```

## Data Persistence

Data is persisted in Docker volumes:
- `elasticsearch_data`: Elasticsearch indices
- `*_logs`: Application logs
- `./data`: Host directory for log files

### Backup Data
```bash
# Backup Elasticsearch data
docker run --rm -v sof-elk_elasticsearch_data:/data -v $(pwd):/backup alpine tar czf /backup/elasticsearch-backup.tar.gz /data

# Restore Elasticsearch data
docker run --rm -v sof-elk_elasticsearch_data:/data -v $(pwd):/backup alpine tar xzf /backup/elasticsearch-backup.tar.gz -C /
```

## Troubleshooting

### Container Won't Start
```bash
# Check container status
docker-compose ps

# Check logs for errors
docker-compose logs <service_name>

# Check resource usage
docker stats
```

### Memory Issues
```bash
# Check available memory
free -h

# Reduce Java heap sizes in docker-compose.yml
ES_JAVA_OPTS: "-Xms1g -Xmx1g"
LS_JAVA_OPTS: "-Xms512m -Xmx512m"
```

### Permission Issues
```bash
# Fix file permissions
sudo chown -R 1000:1000 ./data
sudo chmod -R 755 ./data
```

### Network Issues
```bash
# Check container network
docker network inspect sof-elk_sof-elk-network

# Test connectivity
docker-compose exec logstash curl http://elasticsearch:9200
```

## Development

### Building Images
```bash
docker-compose build                    # Build all images
docker-compose build elasticsearch     # Build specific image
```

### Custom Development Setup
```bash
# Copy override template
cp docker-compose.override.yml.example docker-compose.override.yml

# Edit for your environment
vim docker-compose.override.yml

# Start with overrides
docker-compose up -d
```

## Security Notes

- Default installation disables security features for compatibility
- For production use, enable Elasticsearch security:
  ```yaml
  environment:
    - xpack.security.enabled=true
  ```
- Use proper firewall rules to restrict access
- Consider using Docker secrets for sensitive configurations

## Support

For issues specific to the Docker implementation:
1. Check container logs: `docker-compose logs`
2. Verify system requirements are met
3. Check the main SOF-ELK repository for configuration issues

For SOF-ELK specific questions, refer to the main documentation and GitHub issues.