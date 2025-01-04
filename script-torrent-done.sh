#!/bin/bash

CONFIG_FILE="/app-data/scripts/transmission/transmission-config.yaml"
SCRIPT_LOG="/config/logs/transmission-scripts.log"

source /mnt/Lewis/Media/scripts/lib/shloglib.sh
SHLOG_FILE="$SCRIPT_LOG"
source hardlink_files.sh

# Function to hardlink files recursively to a new destination

# Main function
main() {
    ShLogEnter $FUNCNAME
    
    # Add configuration details printing
    print_config_details
    print_debug_info
    
    local source_dir=$TR_TORRENT_DIR
    local tags=$(echo "$TR_TORRENT_LABELS" | tr ',' ' ')

    ShLogDebug "MAIN: Processing torrent labels: $tags"
    
    if [[ -z "$tags" ]]; then
        ShLogDebug "MAIN: No labels found for torrent '$TR_TORRENT_NAME'"
        ShLogLeave $FUNCNAME
        exit 1
    fi

    for tag in $tags; do
        local destinations=$(read_destinations_from_yaml "$tag")

        if [[ -z "$destinations" ]]; then
            ShLogInfo "MAIN: No destinations found for label $tag"
            continue
        fi

        while IFS= read -r dest_dir; do
            [[ -z "$dest_dir" ]] && continue
            hardlink_files "$source_dir" "$dest_dir"
            ShLogInfo "MAIN: Hardlinked files from $source_dir to $dest_dir for label $tag"
        done <<< "$destinations"
    done
    ShLogLeave $FUNCNAME
}

main
