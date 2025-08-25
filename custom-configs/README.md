# Custom Logstash Configurations

This directory allows you to add custom Logstash configuration files that will be loaded alongside the default SOF-ELK configurations.

## Usage

1. Create `.conf` files in this directory
2. Use appropriate numbering to control processing order:
   - `9100-9199`: Custom input configurations
   - `9200-9299`: Custom filter configurations  
   - `9300-9399`: Custom output configurations

## Example

```ruby
# 9200-custom-app.conf
filter {
  if [fields][log_type] == "myapp" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:msg}" }
    }
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
}
```

## Testing

After adding configurations:
```bash
# Restart Logstash to reload configurations
docker-compose restart logstash

# Check for configuration errors
docker-compose logs logstash
```