#!/bin/bash

hardlink_files() {
    ShLogEnter $FUNCNAME
    local source_dir=$1
    local dest_dir=$2
    
    ShLogDebug "Hardlinking files from '$source_dir' to '$dest_dir'"
    
    if [[ ! -d "$source_dir" ]]; then
        ShLogError "Source directory does not exist: $source_dir"
        ShLogLeave $FUNCNAME
        return 1
    fi
    
    if [[ ! -d "$dest_dir" ]]; then
        ShLogDebug "Creating destination directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    find "$source_dir" -type f -print0 | while IFS= read -r -d '' file; do
        local rel_path="${file#$source_dir/}"
        local target_path="$dest_dir/$rel_path"
        local target_dir=$(dirname "$target_path")
        
        ShLogDebug "Processing file: $file"
        ShLogDebug "Target path: $target_path"
        
        if [[ ! -d "$target_dir" ]]; then
            ShLogDebug "Creating target directory: $target_dir"
            mkdir -p "$target_dir"
        fi
        
        if ln "$file" "$target_path" 2>>"$SCRIPT_LOG"; then
            ShLogDebug "Successfully hardlinked: $file -> $target_path"
        else
            ShLogError "Failed to hardlink: $file -> $target_path"
            ShLogError "Linking error: $(ln "$file" "$target_path" 2>&1)"
        fi
    done
    ShLogLeave $FUNCNAME
}

# Function to read the destination for a tag from an external yaml file
read_destinations_from_yaml() {
    ShLogDebug "Reading destinations for tag: $tag"
    awk -v tag="$tag" '
    BEGIN {in_tags=0; in_tag=0}
    /^torrent-tags:/ {in_tags=1; next}
    in_tags && /^[^[:space:]]/ {in_tags=0; next}
    in_tags && /^[[:space:]]+[^[:space:]]+:/ {
        current_tag=$1
        sub(/:$/, "", current_tag)
        if (current_tag == tag) {
            in_tag=1
            print "DEBUG: RDFY Found tag: " current_tag > "/dev/stderr"
        } else {
            in_tag=0
        }
        next
    }
    in_tag && /^[[:space:]]+-/ {
        destination=$2
        print "DEBUG: RDFY: Found destination for tag " tag ": " destination > "/dev/stderr"
        print destination
    }
    ' "$CONFIG_FILE" 2>> "$SCRIPT_LOG"
}

# Function to print environment variables for debugging
print_debug_info() {
    ShLogEnter $FUNCNAME
    local debug_enabled=$(awk '/^debug_enabled:/{print $2}' "$CONFIG_FILE")
    
    if [[ "$debug_enabled" != "true" ]]; then
        ShLogLeave $FUNCNAME
        return 0
    fi
    
    local vars=(
        "TR_APP_VERSION"
        "TR_TIME_LOCALTIME"
        "TR_TORRENT_BYTES_DOWNLOADED"
        "TR_TORRENT_DIR"
        "TR_TORRENT_HASH"
        "TR_TORRENT_ID"
        "TR_TORRENT_LABELS"
        "TR_TORRENT_NAME"
        "TR_TORRENT_PRIORITY"
        "TR_TORRENT_TRACKERS"
    )
    
    ShLogDebug "=== Debug Information ==="
    for var in "${vars[@]}"; do
        ShLogDebug "$var = ${!var}"
    done
    ShLogDebug "======================="
    ShLogLeave $FUNCNAME
}

# Function to print configuration details
print_config_details() {
    ShLogEnter $FUNCNAME
    ShLogInfo "Using configuration file: $CONFIG_FILE"
    
    # Check if config file exists and is readable
    if [[ ! -f "$CONFIG_FILE" ]]; then
        ShLogError "Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi
    
    if [[ ! -r "$CONFIG_FILE" ]]; then
        ShLogError "Configuration file is not readable: $CONFIG_FILE"
        return 1
    fi
    
    ShLogDebug "Configuration file contents:"
    ShLogDebug "------------------------"
    while IFS= read -r line; do
        ShLogDebug "$line"
    done < "$CONFIG_FILE"
    ShLogDebug "------------------------"
    
    ShLogDebug "Reading configured torrent tags and destinations:"
    # Modified awk command with more verbose output
    awk '
    BEGIN {found_tags=0}
    /^torrent-tags:/ {
        found_tags=1
        print "DEBUG: PCD: Found torrent-tags section"
        next
    }
    found_tags==1 && /^[^[:space:]]/ {
        found_tags=0
        next
    }
    found_tags==1 && /^[[:space:]]+[^[:space:]]+:/ {
        tag=$1
        sub(/:$/, "", tag)
        print "DEBUG: PCD: Processing tag: " tag
    }
    found_tags==1 && /^[[:space:]]+-/ {
        destination=$2
        print "DEBUG: PCD: Found destination for tag " tag ": " destination
    }
    ' "$CONFIG_FILE" >> "$SCRIPT_LOG"
}
