#!/bin/bash

#CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/transmission-config.yaml}"
CONFIG_FILE="/app-data/scripts/transmission/transmission-config.yaml"
SCRIPT_LOG="/config/logs/transmission-scripts.log"

function SCRIPTENTRY(){
    timeAndDate=`date`
    script_name=`basename "$0"`
    script_name="${script_name%.*}"
    echo "[$timeAndDate] [DEBUG]  > $script_name $FUNCNAME" >> $SCRIPT_LOG
}

function SCRIPTEXIT(){
    timeAndDate=`date`
    script_name=`basename "$0"`
    script_name="${script_name%.*}"
    echo "[$timeAndDate] [DEBUG]  < $script_name $FUNCNAME" >> $SCRIPT_LOG
}

function ENTRY(){
    local cfn="${FUNCNAME[1]}"
    timeAndDate=`date`
    echo "[$timeAndDate] [DEBUG]  > $cfn $FUNCNAME" >> $SCRIPT_LOG
}

function EXIT(){
    local cfn="${FUNCNAME[1]}"
    timeAndDate=`date`
    echo "[$timeAndDate] [DEBUG]  < $cfn $FUNCNAME" >> $SCRIPT_LOG
}

function INFO(){
    local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
    echo "[$timeAndDate] [INFO]  $msg" >> $SCRIPT_LOG
}

function DEBUG(){
    local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
    echo "[$timeAndDate] [DEBUG]  $msg" >> $SCRIPT_LOG
}

function ERROR(){
    local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
    echo "[$timeAndDate] [ERROR]  $msg" >> $SCRIPT_LOG
}

# Function to hardlink files recursively to a new destination
hardlink_files() {
    ENTRY
    local source_dir=$1
    local dest_dir=$2
    
    DEBUG "Hardlinking files from '$source_dir' to '$dest_dir'"
    
    if [[ ! -d "$source_dir" ]]; then
        ERROR "Source directory does not exist: $source_dir"
        EXIT
        return 1
    fi
    
    if [[ ! -d "$dest_dir" ]]; then
        DEBUG "Creating destination directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    find "$source_dir" -type f -print0 | while IFS= read -r -d '' file; do
        local rel_path="${file#$source_dir/}"
        local target_path="$dest_dir/$rel_path"
        local target_dir=$(dirname "$target_path")
        
        DEBUG "Processing file: $file"
        DEBUG "Target path: $target_path"
        
        if [[ ! -d "$target_dir" ]]; then
            DEBUG "Creating target directory: $target_dir"
            mkdir -p "$target_dir"
        fi
        
        if ln "$file" "$target_path" 2>>"$SCRIPT_LOG"; then
            DEBUG "Successfully hardlinked: $file -> $target_path"
        else
            ERROR "Failed to hardlink: $file -> $target_path"
            ERROR "Linking error: $(ln "$file" "$target_path" 2>&1)"
        fi
    done
    EXIT
}

# Function to read the destination for a tag from an external yaml file
read_destinations_from_yaml() {
    local tag=$1
    DEBUG "RDFY: Reading destinations for tag: $tag"
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

# Function to initialize log file
init_log_file() {
    ENTRY
    local log_dir=$(dirname "$SCRIPT_LOG")
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            ERROR "Failed to create log directory: $log_dir"
            EXIT
            return 1
        }
    fi
    
    if [[ ! -f "$SCRIPT_LOG" ]]; then
        touch "$SCRIPT_LOG" 2>/dev/null || {
            ERROR "Failed to create log file: $SCRIPT_LOG"
            EXIT
            return 1
        }
    fi
    EXIT
    return 0
}

# Function to print environment variables for debugging
print_debug_info() {
    ENTRY
    local debug_enabled=$(awk '/^debug_enabled:/{print $2}' "$CONFIG_FILE")
    
    if [[ "$debug_enabled" != "true" ]]; then
        EXIT
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
    
    DEBUG "=== Debug Information ==="
    for var in "${vars[@]}"; do
        DEBUG "$var = ${!var}"
    done
    DEBUG "======================="
    EXIT
}

# Function to print configuration details
print_config_details() {
    ENTRY
    INFO "PCD: Using configuration file: $CONFIG_FILE"
    
    # Check if config file exists and is readable
    if [[ ! -f "$CONFIG_FILE" ]]; then
        ERROR "PCD: Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi
    
    if [[ ! -r "$CONFIG_FILE" ]]; then
        ERROR "PCD: Configuration file is not readable: $CONFIG_FILE"
        return 1
    fi
    
    DEBUG "PCD: Configuration file contents:"
    DEBUG "------------------------"
    while IFS= read -r line; do
        DEBUG "$line"
    done < "$CONFIG_FILE"
    DEBUG "------------------------"
    
    DEBUG "PCD: Reading configured torrent tags and destinations:"
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
    
    # # Original tag processing
    # while IFS= read -r line; do
    #     if [[ $line =~ ^[[:space:]]*([^:]+):[[:space:]]*$ ]]; then
    #         local tag="${BASH_REMATCH[1]}"
    #         DEBUG "Tag found: $tag"
    #     fi
    # done < "$CONFIG_FILE"
}
# Main function
main() {
    SCRIPTENTRY
    
    # Add configuration details printing
    print_config_details
    print_debug_info
    
    local source_dir=$TR_TORRENT_DIR
    local tags=$(echo "$TR_TORRENT_LABELS" | tr ',' ' ')

    DEBUG "MAIN: Processing torrent labels: $tags"
    
    if [[ -z "$tags" ]]; then
        DEBUG "MAIN: No labels found for torrent '$TR_TORRENT_NAME'"
        SCRIPTEXIT
        exit 1
    fi

    for tag in $tags; do
        local destinations=$(read_destinations_from_yaml "$tag")

        if [[ -z "$destinations" ]]; then
            INFO "MAIN: No destinations found for label $tag"
            continue
        fi

        while IFS= read -r dest_dir; do
            [[ -z "$dest_dir" ]] && continue
            hardlink_files "$source_dir" "$dest_dir"
            INFO "MAIN: Hardlinked files from $source_dir to $dest_dir for label $tag"
        done <<< "$destinations"
    done
    SCRIPTEXIT
}

main
