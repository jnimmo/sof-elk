# Test Plan for Evtxecmd JSON Processing

## What We Fixed

1. **Path Mapping**: VM paths (`/usr/local/sof-elk/*`) now map to Docker container paths via volume mounts
2. **Filebeat Configuration**: Using the repo's existing filebeat input configs instead of custom ones  
3. **Directory Structure**: Both `/data/kape/` and `/logstash/kape/` paths supported for compatibility

## How Your File Will Be Processed

**File**: `data/kape/20240805055604_EvtxECmd_Output.json`

**Processing Flow**:
1. **Filebeat Detection**: Pattern `/logstash/kape/**/*_EvtxECmd_Output.json` matches your file
2. **Label Assignment**: `labels.type: kape_evtxlogs` automatically added
3. **JSON Parsing**: `tags: ['json']` triggers JSON preprocessing
4. **Logstash Processing**: `configfiles/6504-kape_evtxecmd.conf` processes the labeled data
5. **Elasticsearch Indexing**: Data goes to `evtxlogs-*` index

## To Test This Fix

```bash
# 1. Start SOF-ELK with Filebeat
docker-compose --profile filebeat up -d

# 2. Check that your file is detected
docker logs sof-elk-filebeat | grep -i evtxecmd

# 3. Verify processing in Logstash logs  
docker logs sof-elk-logstash | grep -i kape

# 4. Check Elasticsearch for indexed data
curl -s "localhost:9200/evtxlogs-*/_search?q=*&size=1" | jq .

# 5. View in Kibana
# Open http://localhost:5601
# Go to Discover
# Select "evtxlogs" data view
# You should see your Windows events
```

## Key Files Changed

- `docker-compose.yml`: Added VM path mappings, filebeat input configs
- `docker/filebeat-custom.yml`: Uses dynamic input loading like VM
- `docker/init-elk.sh`: Creates proper directory structure

## Why This Approach is Better

- **Minimal config changes**: Original configfiles untouched, can update from upstream
- **VM compatibility**: Same directory structure and filebeat configs as VM
- **Comprehensive**: Handles all file types the VM supported
- **Future-proof**: New upstream filebeat inputs automatically work