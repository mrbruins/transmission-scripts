# Transmission Torrent-Done Script Configuration Guide

## Overview
This guide explains how to configure the torrent-done script for Transmission, which automatically creates hardlinks of downloaded files based on torrent tags.

## Configuration File
The script uses `transmission-config.yaml` for configuration. Copy the `transmission-config.template.yaml` file to `transmission-config.yaml. Here's how to set it up:

```yaml
torrent-tags:
  tag1:
    - /path/to/destination1
    - /path/to/destination2
  tag2:
    - /path/to/destination3
    - /path/to/destination4
log-file: /path/to/transmission.log
```

### Configuration Structure
- `torrent-tags`: Main section containing tag-to-destination mappings
- Each tag can have multiple destination paths
- `log-file`: Path where script logs will be written

## Usage
1. Add tags to your torrents in Transmission
2. Configure destination paths in `transmission-config.yaml`
3. When a torrent completes:
   - Script checks for tags
   - Creates hardlinks in configured destinations
   - Logs actions to specified log file

## Requirements
- Transmission
- yq (YAML processor)
- Bash shell environment

## Error Handling
The script will log errors if:
- No tags are found for a torrent
- No destinations are configured for a tag