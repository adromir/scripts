#!/bin/bash

# Bash script to automatically create stacks in Immich
# Specifically for stacking a JPG parent with its corresponding RAW children.
# Relies on: jq, curl, mktemp

# Strict mode
set -eo pipefail

# --- Dependency Checks ---
if ! command -v jq &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - 'jq' is not installed or not in PATH. Please install jq (e.g., sudo apt install jq)" >&2
    exit 1
fi
if ! command -v curl &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - 'curl' is not installed or not in PATH. Please install curl (e.g., sudo apt install curl)" >&2
    exit 1
fi
if ! command -v mktemp &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - 'mktemp' is not installed or not in PATH. This is usually part of 'coreutils'." >&2
    exit 1
fi
# --- End Dependency Checks ---


# --- Script Configuration ---
# Please adjust the following variables as needed.

# API_KEY_CONFIG: **Required**. Your Immich API Key.
# This key needs permissions to read asset metadata and to create/modify stacks.
# Example: API_KEY_CONFIG="yourLongAndSecretApiKeyGoesHere"
API_KEY_CONFIG=""

# API_URL_CONFIG: **Required**. The base URL of your Immich instance.
# The script will automatically append '/api' to this URL.
# Example: API_URL_CONFIG="http://immich.example.com:port"
API_URL_CONFIG=""

# SKIP_PREVIOUS_CONFIG: Controls whether to skip assets already in stacks.
# - "true": (Default) The script will skip processing any asset that is already part of a stack
#           (i.e., has a `stackParentId` or its `stack.assetCount` is greater than 0).
#           This is the safer option to avoid altering existing stacks or re-stacking.
# - "false": The script will re-evaluate all assets fetched, even if they are already stacked.
#            This might be useful if you want to try and re-apply stacking logic, but use with caution
#            as it could potentially alter existing stacks or create new ones from already stacked assets
#            if they meet the script's pairing criteria.
SKIP_PREVIOUS_CONFIG="true" 

# DRY_RUN_CONFIG: Controls whether the script makes actual changes or just simulates them.
# - "true": The script will log all actions it *would* take (like creating stacks)
#           but will NOT actually make any changes to your Immich library.
#           **Highly recommended for initial test runs to see what the script intends to do.**
# - "false": Live run mode. The script WILL make changes to your Immich library by creating stacks.
DRY_RUN_CONFIG="false"      

# CRITERIA_DEF_CONFIG: Defines custom criteria for grouping assets if the default RAW+JPEG logic is not used.
# For the default RAW+JPEG workflow, this variable is NOT used, as the logic is hardcoded
# to find JPGs and their corresponding RAWs by basename.
# If you were to modify the script for a more generic stacking approach, you could use this.
# Each element in this Bash array is a string defining a criterion.
# Format examples:
#   "keyName"                     (e.g., "exifInfo.model")
#   "keyName|split|delimiter|index" (e.g., "originalFileName|split|.|0" to get filename without extension)
#   "keyName|regex|pattern|groupIndex" (e.g., "originalFileName|regex|IMG_([0-9]+).*:1" to extract numbers after "IMG_")
# Example: CRITERIA_DEF_CONFIG=("exifInfo.model" "originalFileName|regex|([A-Za-z]+)_.*|1")
CRITERIA_DEF_CONFIG=() 

# PARENT_PROMOTE_CONFIG: Comma-separated list of keywords (case-insensitive).
# If an asset's filename contains any of these keywords, it gets a higher priority
# to be selected as the parent of a stack. This is in addition to the primary rule
# where JPG/JPEG files are strongly preferred as parents for RAW+JPEG stacks.
# Example: PARENT_PROMOTE_CONFIG="COVER,PRIMARY,EDITED"
PARENT_PROMOTE_CONFIG="" 

# SKIP_MATCH_MISS_CONFIG: This variable is NOT USED by the default RAW+JPEG stacking logic.
# It was relevant for a more generic criteria-based stacking where regular expressions
# could be defined in CRITERIA_DEF_CONFIG. It controlled behavior if a regex didn't match.
# For the current specific workflow, this has no effect.
# SKIP_MATCH_MISS_CONFIG="false" 

# CURL_CONNECT_TIMEOUT_CONFIG: Maximum time in seconds that `curl` will spend
# trying to establish a connection to the Immich server for each API request.
CURL_CONNECT_TIMEOUT_CONFIG="15" 

# CURL_MAX_TIME_CONFIG: Maximum total time in seconds that a single `curl` API request
# is allowed to take. If the request (including connection and data transfer)
# exceeds this time, `curl` will time out.
CURL_MAX_TIME_CONFIG="90"        

# ASSET_TYPE_FILTER_CONFIG: Filters the assets fetched from Immich by their type.
# - "IMAGE": (Default) Only assets of type IMAGE will be considered for stacking.
# - "VIDEO": Only assets of type VIDEO will be considered.
# - "":     If left empty, all asset types will be fetched. However, the current stacking
#           logic is primarily designed for images (JPG parent, RAW children).
ASSET_TYPE_FILTER_CONFIG="IMAGE" 

# MAX_ASSETS_TO_PROCESS_CONFIG: Limits the total number of assets fetched from Immich
# for processing. This is useful for testing the script on a smaller subset of your library
# to see how it behaves without waiting for all assets to be processed.
# - "0" or empty/invalid number: All assets matching ASSET_TYPE_FILTER_CONFIG will be fetched.
# - Positive integer (e.g., "200"): Only the first N assets (as returned by the API, usually
#   ordered by recency) will be fetched and processed.
MAX_ASSETS_TO_PROCESS_CONFIG="0" 

# DEBUG_SHOW_JSON_CONFIG: Controls detailed JSON logging for debugging.
# - "true": The script will log the full JSON data of individual asset objects
#           as they are being processed within the `process_single_stack` function.
#           This is very verbose but can be helpful for deep debugging of JSON parsing
#           or data structure issues.
# - "false": (Default) Detailed JSON data is not logged.
DEBUG_SHOW_JSON_CONFIG="false" 

# DEBUG_CURL_COMMAND_CONFIG: Controls logging of `curl` commands.
# - "true": The script will log the complete `curl` command it executes for each API request,
#           including the URL and payload (if any). The API key is sent in headers and
#           will not be directly visible in the logged command string itself for basic security.
# - "false": (Default) `curl` commands are not logged in this detail.
DEBUG_CURL_COMMAND_CONFIG="false"
# --- End Configuration ---


# --- Globale Variablen & Konstanten ---
COMPOUND_KEY_JSON_DELIMITER="@@@JSON_DATA@@@" 
RAW_EXTENSIONS=("dng" "cr2" "cr3" "nef" "arw" "orf" "raf" "rw2" "pef") 

# --- Hilfsfunktionen ---
log_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $1" >/dev/stderr
}
log_warn() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN - $1" >/dev/stderr
}
log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $1" >/dev/stderr
}

str_to_bool_val() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    true|yes|1|on) echo "0" ;; 
    false|no|0|off) echo "1" ;; 
    *) echo "1" ;; 
  esac
}

SKIP_PREVIOUS=$(str_to_bool_val "$SKIP_PREVIOUS_CONFIG")
DRY_RUN=$(str_to_bool_val "$DRY_RUN_CONFIG")
DEBUG_SHOW_JSON=$(str_to_bool_val "$DEBUG_SHOW_JSON_CONFIG")
DEBUG_CURL_COMMAND=$(str_to_bool_val "$DEBUG_CURL_COMMAND_CONFIG")


API_KEY="$API_KEY_CONFIG"
API_URL="$API_URL_CONFIG"
PARENT_PROMOTE_RAW="$PARENT_PROMOTE_CONFIG"
CURL_CONNECT_TIMEOUT="$CURL_CONNECT_TIMEOUT_CONFIG"
CURL_MAX_TIME="$CURL_MAX_TIME_CONFIG"
ASSET_TYPE_FILTER="${ASSET_TYPE_FILTER_CONFIG:-IMAGE}" 

MAX_ASSETS_TO_PROCESS=0 
if [[ "$MAX_ASSETS_TO_PROCESS_CONFIG" =~ ^[1-9][0-9]*$ ]]; then 
    MAX_ASSETS_TO_PROCESS="$MAX_ASSETS_TO_PROCESS_CONFIG"
    log_info "Maximum number of assets to process is set to $MAX_ASSETS_TO_PROCESS."
else
    log_info "No valid limit set for MAX_ASSETS_TO_PROCESS_CONFIG ($MAX_ASSETS_TO_PROCESS_CONFIG), processing all assets."
fi

# --- Immich API Interaktionsfunktionen ---
immich_api_request() {
  local method="$1"
  local endpoint="$2"
  local payload="$3"
  local full_url="${API_URL%/}/api${endpoint}"
  local curl_opts=(
    -s 
    --connect-timeout "$CURL_CONNECT_TIMEOUT" 
    --max-time "$CURL_MAX_TIME"            
    --retry 3                              
    --retry-delay 2 
    --retry-connrefused                     
    -H "x-api-key: ${API_KEY}"
    -H "Accept: application/json"
  )

  if [ "$method" == "POST" ] || [ "$method" == "PUT" ] || [ "$method" == "DELETE" ]; then
    curl_opts+=(-H "Content-Type: application/json")
  fi

  local response http_code
  if [ "$DEBUG_CURL_COMMAND" -eq 0 ]; then # 0 is true
    log_info "    curl: $method $full_url (Connect-Timeout: ${CURL_CONNECT_TIMEOUT}s, Max-Time: ${CURL_MAX_TIME}s)"
    if [ -n "$payload" ]; then
        log_info "    Payload: $payload"
    fi
  fi
  
  if [ -n "$payload" ]; then
    response=$(curl "${curl_opts[@]}" -X "$method" -d "$payload" -w "\n%{http_code}" "$full_url")
  else
    response=$(curl "${curl_opts[@]}" -X "$method" -w "\n%{http_code}" "$full_url")
  fi
  
  local curl_exit_code=$?
  if [ $curl_exit_code -ne 0 ]; then
      log_error "curl command itself failed with exit code $curl_exit_code for $method $full_url."
      if [ $curl_exit_code -eq 28 ]; then 
          log_error "curl timeout reached for $method $full_url."
      elif [ $curl_exit_code -eq 6 ]; then 
          log_error "curl could not resolve host: $full_url"
      elif [ $curl_exit_code -eq 7 ]; then 
          log_error "curl could not connect to: $full_url"
      fi
      return 1 
  fi
  
  http_code=$(echo -e "$response" | tail -n1)
  response_body=$(echo -e "$response" | sed '$d')

  local is_json_valid=true
  if [ "$method" == "POST" ] && [ "$endpoint" == "/stacks" ] && [ "$http_code" -eq 201 ]; then
      is_json_valid=true 
  elif [ "$method" == "DELETE" ] && [ "$endpoint" == "/stacks" ] && [ "$http_code" -eq 204 ]; then
      is_json_valid=true
  elif [ "$method" == "PUT" ] && [[ "$endpoint" == "/assets/stack/remove" ]] && [ "$http_code" -eq 200 ]; then 
      is_json_valid=true 
  elif ! echo "$response_body" | jq empty > /dev/null 2>&1; then
      is_json_valid=false
      if ! [[ "$http_code" -ge 200 && "$http_code" -lt 300 && -z "$response_body" ]]; then 
        log_error "API response body is not valid JSON (HTTP $http_code): $method $full_url"
        log_error "API response body (shortened): $(echo "$response_body" | head -c 500)..."
      fi
  fi

  if [ "$method" == "POST" ] && [ "$endpoint" == "/stacks" ]; then
      if [ "$http_code" -eq 201 ]; then 
          echo "$response_body" 
          return 0
      else
          log_error "API request POST /api/stacks failed (HTTP $http_code): $method $full_url"
          log_error "Response body: $response_body" 
          return 1
      fi
  elif [ "$method" == "DELETE" ] && [ "$endpoint" == "/stacks" ]; then
      if [ "$http_code" -eq 204 ]; then 
          log_info "    API call DELETE /api/stacks successful (HTTP 204 No Content)."
          return 0
      else
          log_error "API request DELETE /api/stacks failed (HTTP $http_code): $method $full_url"
          log_error "Response body: $response_body" 
          return 1
      fi
  elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    if $is_json_valid; then
        echo "$response_body" 
        return 0
    else
        if [ -z "$response_body" ]; then 
            log_info "    API call successful (HTTP $http_code) with empty response body."
            return 0
        fi
        log_warn "API reported success (HTTP $http_code for $method $endpoint), but the response body was not valid JSON. Treating as an error."
        return 1 
    fi
  else 
    log_error "API request failed (HTTP $http_code): $method $full_url"
    if ! $is_json_valid && [ -n "$response_body" ]; then
        : 
    elif [ -n "$response_body" ]; then 
        log_error "Response body: $response_body"
    fi
    return 1
  fi
}

fetch_assets() {
  local page_size=1000 current_page=1 total_assets_fetched=0 all_fetched_assets_json=""
  local last_api_next_page_value="" 
  local page_repeat_count=0
  local assets_limit_reached=false

  log_info "Starting to fetch assets from Immich (Type filter: $ASSET_TYPE_FILTER)..."
  log_info "    Page size for API requests: $page_size"
  if [ "$MAX_ASSETS_TO_PROCESS" -gt 0 ]; then
      log_info "    Limit: A maximum of $MAX_ASSETS_TO_PROCESS assets will be fetched and considered for stacking."
  fi

  while [ -n "$current_page" ]; do
    if $assets_limit_reached; then 
        log_info "    Asset limit of $MAX_ASSETS_TO_PROCESS reached. Stopping further fetching."
        break
    fi

    local payload response_json current_page_candidate assets_array_str
    
    # Determine the value for withStacked based on SKIP_PREVIOUS setting
    local with_stacked_param_value="true" # Default for when SKIP_PREVIOUS is false (consider all assets)
    if [ "$SKIP_PREVIOUS" -eq 0 ]; then # SKIP_PREVIOUS_CONFIG is "true" (requesting only unstacked)
        # If we only want to process unstacked assets, the API might be able to filter them directly.
        # However, to be safe and ensure we get stack.assetCount for potential parents,
        # it might be better to always fetch withStacked:true and filter locally.
        # For now, we'll rely on local filtering in Step 2 if SKIP_PREVIOUS is true.
        # The API call for /search/metadata does not seem to have a direct "isNotStacked" filter.
        # 'withStacked: false' might mean "don't include stack info", not "only unstacked".
        # Therefore, always fetching with 'withStacked: true' and filtering locally is more robust.
        log_info "    SKIP_PREVIOUS is true. Assets will be fetched with stack info and filtered locally."
    else
        log_info "    SKIP_PREVIOUS is false. Assets will be fetched with stack info."
    fi
    
    local payload_jq_args=("--argjson" "size" "$page_size" "--argjson" "page" "$current_page" "--argjson" "withStacked" "true") # Always fetch with stack info
    if [ -n "$ASSET_TYPE_FILTER" ]; then
        payload_jq_args+=("--arg" "type" "$ASSET_TYPE_FILTER")
        payload=$(jq -n "${payload_jq_args[@]}" '{size: $size, page: $page, withStacked: $withStacked, type: $type}')
    else
        payload=$(jq -n "${payload_jq_args[@]}" '{size: $size, page: $page, withStacked: $withStacked}')
    fi

    log_info "    Requesting assets - Page: $current_page" 
    
    response_json=$(immich_api_request "POST" "/search/metadata" "$payload")
    if [ $? -ne 0 ]; then 
        log_error "Critical error fetching assets page $current_page (API request failed). Aborting asset fetch."
        return 1 
    fi

    current_page_candidate=$(echo "$response_json" | jq -r '.assets.nextPage // empty' 2>/dev/null)
    if [ $? -ne 0 ]; then 
        log_warn "    Could not extract nextPage from API response for page $current_page. Response was likely not valid JSON or structure is unexpected."
        log_warn "    API response (shortened): $(echo "$response_json" | head -c 300)..."
        current_page="" 
        continue 
    fi
    if [ "$current_page_candidate" == "null" ]; then 
        current_page_candidate=""
    fi

    assets_array_str=$(echo "$response_json" | jq -c '.assets.items' 2>/dev/null)
    if [ $? -ne 0 ]; then 
        log_warn "    Could not extract asset array '.assets.items' from API response for page $current_page."
        log_warn "    API response (shortened): $(echo "$response_json" | head -c 300)..."
        current_page="$current_page_candidate" 
        if [ -n "$current_page_candidate" ] && [ "$current_page_candidate" == "$last_api_next_page_value" ]; then
            page_repeat_count=$((page_repeat_count + 1))
            if [ "$page_repeat_count" -gt 3 ]; then
                log_error "    The API seems to be returning the same nextPage ($current_page_candidate) repeatedly (after item extraction error). Aborting pagination."
                current_page="" 
            fi
        else page_repeat_count=0; fi
        last_api_next_page_value="$current_page_candidate"
        continue
    fi

    if ! echo "$assets_array_str" | jq -e 'if type=="array" then true else false end' > /dev/null 2>&1; then
        log_warn "    Extracted '.assets.items' from API response for page $current_page is not a valid JSON array."
        log_warn "    Extracted string for .assets.items (shortened): $(echo "$assets_array_str" | head -c 200)..."
        current_page="$current_page_candidate" 
        if [ -n "$current_page_candidate" ] && [ "$current_page_candidate" == "$last_api_next_page_value" ]; then
            page_repeat_count=$((page_repeat_count + 1))
            if [ "$page_repeat_count" -gt 3 ]; then
                log_error "    The API seems to be returning the same nextPage ($current_page_candidate) repeatedly (after array validation error). Aborting pagination."
                current_page="" 
            fi
        else page_repeat_count=0; fi
        last_api_next_page_value="$current_page_candidate"
        continue
    fi
    
    local count_on_page=0
    local single_item_json
    while IFS= read -r single_item_json; do
        if [ -z "$single_item_json" ]; then continue; fi 
        
        if [ "$MAX_ASSETS_TO_PROCESS" -gt 0 ] && [ "$total_assets_fetched" -ge "$MAX_ASSETS_TO_PROCESS" ]; then
            assets_limit_reached=true
            log_info "    Maximum asset limit of $MAX_ASSETS_TO_PROCESS reached. Stopping addition of more assets from this page."
            break 
        fi
        
        local final_item_json="$single_item_json"
        if echo "$single_item_json" | jq -e 'if type=="array" and length==1 and (.[0] | type=="object") then true else false end' > /dev/null 2>&1; then
            final_item_json=$(echo "$single_item_json" | jq -c '.[0]')
        fi

        if echo "$final_item_json" | jq -e 'if type=="object" then true else false end' > /dev/null 2>&1; then
            all_fetched_assets_json+="${final_item_json}"$'\n'
            count_on_page=$((count_on_page + 1))
            total_assets_fetched=$((total_assets_fetched + 1)) 
        else
            log_warn "    Skipping invalid JSON object (not an object after potential array extraction) in asset array on page $current_page:"
            log_warn "    Data:$final_item_json" 
        fi
    done < <(echo "$assets_array_str" | jq -c '.[]' 2>/dev/null) 
    
    log_info "    Page $current_page processed successfully, $count_on_page valid assets added. Total so far: $total_assets_fetched"
    
    if $assets_limit_reached; then
        current_page="" 
    else
        if [ -n "$current_page_candidate" ] && [ "$current_page_candidate" == "$last_api_next_page_value" ]; then
            page_repeat_count=$((page_repeat_count + 1))
            if [ "$page_repeat_count" -gt 3 ]; then 
                log_error "    The API seems to be returning the same nextPage ($current_page_candidate) $page_repeat_count times in a row. Aborting pagination to prevent infinite loop."
                current_page="" 
            else
                log_warn "    API returned the same nextPage ($current_page_candidate) $page_repeat_count times. Continuing pagination."
            fi
        else
            page_repeat_count=0 
        fi
        last_api_next_page_value="$current_page_candidate" 
        current_page="$current_page_candidate" 
    fi

    if [ -z "$current_page" ] && ! $assets_limit_reached ; then 
        log_info "    End of pagination reached (nextPage is empty)."
    fi
  done

  log_info "Asset fetching complete. Total $total_assets_fetched valid assets received from Immich and selected for processing."
  if [ "$total_assets_fetched" -eq 0 ]; then log_warn "No valid assets fetched from Immich."; fi
  echo -n "$all_fetched_assets_json"
}

create_new_stack() {
  local parent_id="$1"
  shift 
  local children_ids_array=("$@") 

  if [ ${#children_ids_array[@]} -eq 0 ]; then
      log_warn "    No child IDs provided for stacking with parent $parent_id."
      return 1
  fi

  local asset_ids_for_payload=("$parent_id")
  asset_ids_for_payload+=("${children_ids_array[@]}")

  local stack_payload_asset_ids
  stack_payload_asset_ids=$(printf '%s\n' "${asset_ids_for_payload[@]}" | jq -R . | jq -s .) 
  
  local stack_payload
  stack_payload=$(jq -n --argjson ids "$stack_payload_asset_ids" '{assetIds: $ids}')
  
  log_info "    Sending request to create stack to Immich API (POST /api/stacks)..."
  log_info "    Parent ID (first element in assetIds): $parent_id, Child IDs: ${children_ids_array[*]}"
  
  if immich_api_request "POST" "/stacks" "$stack_payload"; then 
    log_info "    API call to create stack successful!"
  else
    log_error "    ERROR in API call to create stack!"
  fi
}

get_base_filename() {
    local filename="$1"
    if [[ "$filename" == *.* && "$filename" != "." && "$filename" != ".." ]]; then
        echo "${filename%.*}"
    else
        echo "$filename" 
    fi
}

get_file_extension() {
    local filename="$1"
    local extension=""
    if [[ "$filename" == *.* && "$filename" != "." && "$filename" != ".." ]]; then
        extension="${filename##*.}"
    fi
    echo "${extension,,}" 
}

is_raw_extension() {
    local ext_to_check="$1"
    local raw_ext
    if [ -z "$ext_to_check" ]; then return 1; fi 
    for raw_ext in "${RAW_EXTENSIONS[@]}"; do
        if [ "$ext_to_check" == "$raw_ext" ]; then
            return 0 
        fi
    done
    return 1 
}

get_json_field() {
    local json_input="$1"
    local field_path="$2" 
    local default_value="${3:-empty_if_not_found}" 

    local temp_obj_json="$json_input"
    if echo "$json_input" | jq -e 'if type=="array" and length==1 and (.[0] | type=="object") then true else false end' > /dev/null 2>&1; then
        temp_obj_json=$(echo "$json_input" | jq -c '.[0]' 2>/dev/null)
        if [ $? -ne 0 ]; then 
             if [ "$default_value" == "empty_if_not_found" ]; then echo ""; else echo "$default_value"; fi
             return
        fi
    elif ! echo "$json_input" | jq -e 'if type=="object" then true else false end' > /dev/null 2>&1; then
        log_warn "get_json_field: Input is neither a valid JSON object nor a single-object array: $(echo "$json_input" | head -c 50)..."
        if [ "$default_value" == "empty_if_not_found" ]; then echo ""; else echo "$default_value"; fi
        return
    fi
    
    local value
    value=$(echo "$temp_obj_json" | jq -r "$field_path // \"$default_value\"" 2>/dev/null)

    if [ $? -ne 0 ] || \
       { [ "$value" == "$default_value" ] && [ "$default_value" != "empty_if_not_found" ]; } || \
       { [ "$value" == "null" ] && [ "$default_value" == "empty_if_not_found" ]; }; then
        if [ "$default_value" == "empty_if_not_found" ]; then
             echo "" 
        else
             echo "$default_value"
        fi
    else
        echo "$value"
    fi
}


get_parent_sort_key_for_asset_json() {
  local asset_json="$1"
  local original_file_name
  original_file_name=$(get_json_field "$asset_json" '.originalFileName' "FilenameMissing")
  
  local lower_filename
  lower_filename=$(echo "$original_file_name" | tr '[:upper:]' '[:lower:]')
  
  local parent_promote_baseline=0
  
  if [[ "$lower_filename" == *.jpg ]] || [[ "$lower_filename" == *.jpeg ]]; then
    parent_promote_baseline=$((parent_promote_baseline - 200))
  elif [[ "$lower_filename" == *.png ]]; then
    parent_promote_baseline=$((parent_promote_baseline - 100))
  elif is_raw_extension "$(get_file_extension "$lower_filename")"; then
    parent_promote_baseline=$((parent_promote_baseline + 100)) 
  fi

  if [ -n "$PARENT_PROMOTE_RAW" ]; then
    IFS=',' read -ra promote_keywords <<< "$PARENT_PROMOTE_RAW"
    for keyword in "${promote_keywords[@]}"; do
      if [ -n "$keyword" ]; then 
          local lower_keyword=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower_filename" == *"$lower_keyword"* ]]; then 
            log_info "    Parent prioritization: '$original_file_name' gets bonus due to keyword '$keyword'."
            parent_promote_baseline=$((parent_promote_baseline - 10)) 
        fi
      fi
    done
  fi
  echo -e "${parent_promote_baseline}\t${original_file_name}"
}

# --- Main Logic ---
main() {
  log_info "============== SCRIPT START: IMMICH AUTO-STACKING (RAW+JPEG) =============="
  if [ -z "$API_KEY" ]; then
    log_error "API_KEY_CONFIG is not set in the script. Please configure and try again. Exiting."
    exit 1
  fi
  log_info "API Key: [CONFIGURED]"
  log_info "API URL: $API_URL"
  log_info "SKIP_PREVIOUS: $SKIP_PREVIOUS_CONFIG (interpreted as: $SKIP_PREVIOUS)" 
  log_info "DRY_RUN: $DRY_RUN_CONFIG (interpreted as: $DRY_RUN)"
  log_info "PARENT_PROMOTE: '$PARENT_PROMOTE_RAW'"
  log_info "CURL Connect Timeout: ${CURL_CONNECT_TIMEOUT}s, Max Time: ${CURL_MAX_TIME}s"
  log_info "ASSET TYPE FILTER: $ASSET_TYPE_FILTER"
  if [ "$MAX_ASSETS_TO_PROCESS" -gt 0 ]; then
      log_info "MAX ASSETS TO PROCESS: $MAX_ASSETS_TO_PROCESS"
  fi
  if [ "$DEBUG_SHOW_JSON" -eq 0 ]; then 
      log_info "DEBUG_SHOW_JSON is enabled. JSON objects will be logged in process_single_stack."
  fi
  if [ "$DEBUG_CURL_COMMAND" -eq 0 ]; then
      log_info "DEBUG_CURL_COMMAND is enabled. Curl commands will be logged."
  fi


  if [ "$DRY_RUN" -eq "0" ]; then 
    log_warn "ATTENTION: Dry run (DRY_RUN) is enabled. NO changes will be made to your Immich library."
  else 
    log_info "Mode: Live run. Changes will be sent to Immich."
  fi

  log_info "Step 1: Fetching all assets from Immich..."
  local all_assets_json_lines total_initial_assets
  all_assets_json_lines=$(fetch_assets) 
  if [ $? -ne 0 ]; then 
      log_error "Asset fetching failed in fetch_assets. Exiting."
      exit 1; 
  fi
  
  if [ -z "$all_assets_json_lines" ]; then
      total_initial_assets=0
  else
      total_initial_assets=$(echo "$all_assets_json_lines" | grep -c '[^[:space:]]') 
  fi

  if [ "$total_initial_assets" -eq 0 ]; then
      log_warn "No valid assets found from Immich to process. Exiting script."
      log_info "============== SCRIPT END =============="; exit 0;
  fi
  log_info "$total_initial_assets valid assets successfully fetched from Immich and selected for processing."
  
  local free_jpg_assets_tmp; free_jpg_assets_tmp=$(mktemp)    
  local free_raw_assets_tmp; free_raw_assets_tmp=$(mktemp)    
  local potential_stacks_tmp; potential_stacks_tmp=$(mktemp) 
  local sorted_assets_tmp; sorted_assets_tmp=$(mktemp) 
  
  trap 'rm -f "$free_jpg_assets_tmp" "$free_raw_assets_tmp" "$potential_stacks_tmp" "$sorted_assets_tmp"' EXIT 


  log_info "Step 2: Filtering assets and identifying free JPGs and RAWs..."
  local asset_count_processed_in_step2=0 
  local free_jpg_count=0
  local free_raw_count=0
  local filtered_out_due_to_existing_stack=0
  
  local all_asset_lines_array_for_step2=()
  mapfile -t all_asset_lines_array_for_step2 <<< "$all_assets_json_lines"

  for asset_json_line in "${all_asset_lines_array_for_step2[@]}"; do
    asset_count_processed_in_step2=$((asset_count_processed_in_step2 + 1))
    echo -ne "    Checking asset $asset_count_processed_in_step2/$total_initial_assets for stack status and type...\r" >/dev/stderr 

    if [ -z "$asset_json_line" ]; then continue; fi
    
    if ! echo "$asset_json_line" | jq empty > /dev/null 2>&1; then
        log_warn "    Skipping invalid JSON line in Step 2: $(echo "$asset_json_line" | head -c 100)..."
        continue
    fi
    
    local stack_parent_id asset_stack_count original_filename lower_filename extension
    stack_parent_id=$(get_json_field "$asset_json_line" '.stackParentId' "null") 
    
    if echo "$asset_json_line" | jq -e '.stack' > /dev/null 2>&1; then 
        asset_stack_count=$(get_json_field "$asset_json_line" '.stack.assetCount' "0")
    else
        asset_stack_count="0" 
    fi

    # If SKIP_PREVIOUS is true (0), then skip if already stacked
    if [ "$SKIP_PREVIOUS" -eq 0 ]; then 
        if [ "$stack_parent_id" != "null" ] || { [ "$asset_stack_count" != "0" ] && [ "$asset_stack_count" != "null" ]; }; then
            filtered_out_due_to_existing_stack=$((filtered_out_due_to_existing_stack + 1))
            continue
        fi
    fi
    
    original_filename=$(get_json_field "$asset_json_line" '.originalFileName' "")
    if [ -z "$original_filename" ]; then continue; fi 
    lower_filename=$(echo "$original_filename" | tr '[:upper:]' '[:lower:]')
    extension=$(get_file_extension "$lower_filename")

    if [[ "$extension" == "jpg" ]] || [[ "$extension" == "jpeg" ]]; then
        echo "$asset_json_line" >> "$free_jpg_assets_tmp"
        free_jpg_count=$((free_jpg_count + 1))
    elif is_raw_extension "$extension"; then
        echo "$asset_json_line" >> "$free_raw_assets_tmp"
        free_raw_count=$((free_raw_count + 1))
    fi
  done
  echo >/dev/stderr 
  log_info "Step 2 complete: $asset_count_processed_in_step2 assets checked."
  log_info "    $filtered_out_due_to_existing_stack assets skipped (already stacked and SKIP_PREVIOUS is true)."
  log_info "    $free_jpg_count free JPG/JPEG assets found."
  log_info "    $free_raw_count free RAW assets found."

  if [ ! -s "$free_jpg_assets_tmp" ] || [ ! -s "$free_raw_assets_tmp" ]; then
      log_warn "No free JPGs or no free RAWs found. No stacks can be formed."
      log_info "============== SCRIPT END =============="; exit 0;
  fi

  log_info "Step 3: Finding matching JPG and RAW pairs..."
  local potential_stack_groups_count=0
  
  declare -A raw_map_by_basename 
  while IFS= read -r raw_json_line; do
      if [ -z "$raw_json_line" ]; then continue; fi
      local raw_filename raw_basename
      raw_filename=$(get_json_field "$raw_json_line" '.originalFileName')
      raw_basename=$(get_base_filename "$raw_filename")
      if [ -n "${raw_map_by_basename[$raw_basename]}" ]; then
          raw_map_by_basename[$raw_basename]+="${COMPOUND_KEY_JSON_DELIMITER}${raw_json_line}" 
      else
          raw_map_by_basename[$raw_basename]="${raw_json_line}"
      fi
  done < "$free_raw_assets_tmp"


  while IFS= read -r jpg_json_line; do
      if [ -z "$jpg_json_line" ]; then continue; fi
      local jpg_filename jpg_basename
      jpg_filename=$(get_json_field "$jpg_json_line" '.originalFileName')
      jpg_basename=$(get_base_filename "$jpg_filename")

      if [ -n "${raw_map_by_basename[$jpg_basename]}" ]; then
          log_info "    Potential stack for basename '$jpg_basename' (JPG: $jpg_filename)"
          echo -n "${jpg_basename}${COMPOUND_KEY_JSON_DELIMITER}${jpg_json_line}" >> "$potential_stacks_tmp"
          
          local raw_json_block="${raw_map_by_basename[$jpg_basename]}"
          echo "${COMPOUND_KEY_JSON_DELIMITER}${raw_json_block}" >> "$potential_stacks_tmp" 
          
          potential_stack_groups_count=$((potential_stack_groups_count + 1))
      fi
  done < "$free_jpg_assets_tmp"
  log_info "Step 3 complete: $potential_stack_groups_count potential stack groups identified."

  if [ ! -s "$potential_stacks_tmp" ]; then
      log_warn "No matching JPG/RAW pairs found for stacking."
      log_info "============== SCRIPT END =============="; exit 0;
  fi
  
  cp "$potential_stacks_tmp" "$sorted_assets_tmp" 


  log_info "Step 4: Processing identified stack groups..."
  local stack_counter=0 groups_processed_count=0 
  
  if [ ! -s "$sorted_assets_tmp" ]; then 
      log_warn "No stack groups to process."
  else
      total_potential_stacks=$(wc -l < "$sorted_assets_tmp") 
      log_info "    $total_potential_stacks potential stack groups to process."

      local line_from_file jpg_asset_json stack_group_basename
      
      while IFS= read -r line_from_file || [ -n "$line_from_file" ]; do 
        if [ -z "$line_from_file" ]; then continue; fi
        groups_processed_count=$((groups_processed_count + 1))

        stack_group_basename="${line_from_file%%${COMPOUND_KEY_JSON_DELIMITER}*}"
        local data_after_basename="${line_from_file#*${COMPOUND_KEY_JSON_DELIMITER}}"
        
        jpg_asset_json="${data_after_basename%%${COMPOUND_KEY_JSON_DELIMITER}*}"
        local remaining_raw_data="${data_after_basename#*${COMPOUND_KEY_JSON_DELIMITER}}"
        
        if [ "$jpg_asset_json" == "$data_after_basename" ] && [ "$remaining_raw_data" == "$jpg_asset_json" ]; then 
            remaining_raw_data=""
        fi

        local current_group_for_processing=()
        if [ -n "$jpg_asset_json" ]; then 
            current_group_for_processing+=("$jpg_asset_json")
        else
            log_warn "    Invalid group for basename '$stack_group_basename': No JPG asset found. Skipping."
            continue
        fi
        
        if [ -n "$remaining_raw_data" ]; then 
            local temp_raw_data_for_split="$remaining_raw_data"
            local raw_asset_json_parts_array_temp=() 
            while true; do
                local single_raw_json="${temp_raw_data_for_split%%${COMPOUND_KEY_JSON_DELIMITER}*}"
                if [ -n "$single_raw_json" ]; then
                    raw_asset_json_parts_array_temp+=("$single_raw_json")
                fi
                if [[ "$temp_raw_data_for_split" == *"$COMPOUND_KEY_JSON_DELIMITER"* ]]; then
                    temp_raw_data_for_split="${temp_raw_data_for_split#*${COMPOUND_KEY_JSON_DELIMITER}}"
                else
                    break 
                fi
            done
            for raw_json_val in "${raw_asset_json_parts_array_temp[@]}"; do
                 current_group_for_processing+=("$raw_json_val")
            done
        fi
        
        if [ "${#current_group_for_processing[@]}" -lt 2 ]; then 
            log_info "    Group for basename '$stack_group_basename' does not have enough assets (JPG + at least 1 RAW). Skipping."
            continue
        fi

        echo -ne "    Processing group $groups_processed_count/$total_potential_stacks (Basename: [$stack_group_basename])...\r" >/dev/stderr
        
        process_single_stack "$stack_group_basename" "${current_group_for_processing[@]}" 
        stack_counter=$((stack_counter + 1)) 

      done < "$sorted_assets_tmp"
      echo >/dev/stderr 
  fi 
  
  log_info "Group processing complete."
  log_info "    $stack_counter stack groups were processed." 
  log_info "============== SCRIPT END =============="
}

process_single_stack() {
  local stack_key="$1"; shift; 
  local group_asset_json_strings=("$@") 
  log_info "    Stack processing for basename ['${stack_key}'] with ${#group_asset_json_strings[@]} assets:"

  local stratified_stack_tmp_local; stratified_stack_tmp_local=$(mktemp) 
  trap 'rm -f "$free_jpg_assets_tmp" "$free_raw_assets_tmp" "$potential_stacks_tmp" "$sorted_assets_tmp" "$stratified_stack_tmp_local"' EXIT


  for asset_json_part_loop in "${group_asset_json_strings[@]}"; do
    local asset_to_process="$asset_json_part_loop"
    if echo "$asset_json_part_loop" | jq -e 'if type=="array" and length==1 and (.[0] | type=="object") then true else false end' > /dev/null 2>&1; then
        asset_to_process=$(echo "$asset_json_part_loop" | jq -c '.[0]')
    fi

    if [ "$DEBUG_SHOW_JSON" -eq 0 ]; then 
        log_info "DEBUG_JSON process_single_stack: asset_to_process for basename '$stack_key' before validation:"
        log_info "${asset_to_process}" 
        log_info "--- END DEBUG_JSON ---"
    fi

    if ! echo "$asset_to_process" | jq empty > /dev/null 2>&1; then
        log_warn "      Invalid JSON object in stack for basename '$stack_key' skipped for stratification."
        log_warn "      JSON data (shortened):" 
        log_warn "      $(echo "$asset_to_process" | head -c 100)..."
        continue 
    fi
    local parent_sort_key; parent_sort_key=$(get_parent_sort_key_for_asset_json "$asset_to_process")
    echo -e "${parent_sort_key}\t${asset_to_process}" >> "$stratified_stack_tmp_local"
  done
  
  if [ ! -s "$stratified_stack_tmp_local" ]; then
      log_warn "      No valid assets found for stratification for basename '$stack_key'."
      rm -f "$stratified_stack_tmp_local"
      return
  fi
  sort "$stratified_stack_tmp_local" -o "$stratified_stack_tmp_local" 

  local stratified_assets_array=(); mapfile -t stratified_assets_array < <(cut -f3- "$stratified_stack_tmp_local") 
  
  if [ ${#stratified_assets_array[@]} -eq 0 ]; then
      log_warn "      Could not read assets for stratification for stack basename '$stack_key' (after cut). Skipping this stack."
      rm -f "$stratified_stack_tmp_local" 
      return
  fi

  local parent_asset_json="${stratified_assets_array[0]}"
  if ! echo "$parent_asset_json" | jq empty > /dev/null 2>&1; then 
      log_error "      Parent asset JSON for basename '$stack_key' is invalid: $(echo "$parent_asset_json" | head -c 100)... Skipping this stack."
      rm -f "$stratified_stack_tmp_local"
      return 
  fi
  
  local parent_id; parent_id=$(get_json_field "$parent_asset_json" '.id')
  local parent_filename; parent_filename=$(get_json_field "$parent_asset_json" '.originalFileName' "FilenameMissingInParent")
  
  local parent_ext; parent_ext=$(get_file_extension "$parent_filename")
  if [[ "$parent_ext" != "jpg" ]] && [[ "$parent_ext" != "jpeg" ]]; then
      log_warn "      Selected parent '$parent_filename' for basename '$stack_key' is not a JPG/JPEG. Skipping this stack."
      rm -f "$stratified_stack_tmp_local"
      return
  fi
  log_info "      Parent selected (JPG): '$parent_filename' (ID: $parent_id)"


  local children_ids=() child_info_log=() new_children_count=0
  for i in $(seq 1 $((${#stratified_assets_array[@]} - 1))); do
    local child_asset_json="${stratified_assets_array[$i]}"
    if ! echo "$child_asset_json" | jq empty > /dev/null 2>&1; then 
        log_warn "      Invalid child asset JSON for basename '$stack_key' skipped: $(echo "$child_asset_json" | head -c 100)..."
        continue
    fi

    local child_id child_filename child_stack_count
    child_id=$(get_json_field "$child_asset_json" '.id')
    child_filename=$(get_json_field "$child_asset_json" '.originalFileName' "FilenameMissingInChild")
    child_stack_count=$(get_json_field "$child_asset_json" '.stackCount' "0") 
    local child_stack_parent_id=$(get_json_field "$child_asset_json" '.stackParentId' "null")

    if [ "$child_stack_parent_id" != "null" ]; then
        child_info_log+=("        Child SKIPPED (already child): '$child_filename' (ID: $child_id, Parent: $child_stack_parent_id)")
        continue
    fi
    if [ "$child_stack_count" != "0" ]; then
        child_info_log+=("        Child SKIPPED (already parent): '$child_filename' (ID: $child_id, stackCount: $child_stack_count)")
        continue
    fi

    local child_ext; child_ext=$(get_file_extension "$child_filename")
    if ! is_raw_extension "$child_ext"; then
        child_info_log+=("        Child SKIPPED (not a RAW file): '$child_filename'")
        continue
    fi
    
    if [ "$SKIP_PREVIOUS" -eq "0" ]; then 
      if [ "$child_stack_count" == "0" ] && [ "$child_stack_parent_id" == "null" ]; then
        children_ids+=("$child_id")
        child_info_log+=("        Child ADDED (RAW): '$child_filename' (ID: $child_id, Not previously stacked)")
        new_children_count=$((new_children_count + 1))
      else
        child_info_log+=("        Child SKIPPED (RAW, already stacked or parent - redundant check): '$child_filename' (ID: $child_id, stackCount: $child_stack_count, stackParentId: $child_stack_parent_id)")
      fi
    else 
      children_ids+=("$child_id")
      child_info_log+=("        Child ADDED (RAW, SKIP_PREVIOUS=false): '$child_filename' (ID: $child_id)")
      new_children_count=$((new_children_count + 1))
    fi
  done

  if [ ${#child_info_log[@]} -gt 0 ]; then
    log_info "      Child assets for basename '$stack_key':"; for log_line in "${child_info_log[@]}"; do log_info "$log_line"; done
  else
    if [ "$new_children_count" -eq 0 ]; then 
        log_info "      No suitable (RAW) child assets found for this JPG parent for basename '$stack_key' (or all skipped)."
    fi
  fi

  if [ "$new_children_count" -gt 0 ]; then
    if [ "$DRY_RUN" -eq "0" ]; then 
      log_warn "      DRY RUN: Would stack $new_children_count new RAW child(ren) under JPG parent '$parent_filename' (ID: $parent_id)."
    else 
      log_info "      ACTION: Stacking $new_children_count new RAW child(ren) under JPG parent '$parent_filename' (ID: $parent_id)."
      create_new_stack "$parent_id" "${children_ids[@]}" 
    fi
  else
    log_info "      No new or suitable RAW children to stack for JPG parent '$parent_filename' (ID: $parent_id) in this run."
  fi
  rm -f "$stratified_stack_tmp_local" 
  log_info "    Processing for basename ['${stack_key}'] complete." 
}

main
