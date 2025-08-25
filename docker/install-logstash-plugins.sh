#!/bin/bash
# Install missing Logstash plugins for SOF-ELK compatibility

echo "Installing missing Logstash plugins..."

# Install json_encode plugin
logstash-plugin install logstash-filter-json_encode

# Install relp input plugin  
logstash-plugin install logstash-input-relp

echo "Plugin installation completed"