#!/bin/bash

# Bash script to unstack all assets in Immich.
# It identifies JPG assets, queries /api/stacks?primaryAssetId={assetId}
# to find stack entities, collects unique stack IDs into an array, 
# and then sends a single DELETE request to /api/stacks with all those stack IDs.

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
# mktemp is no longer needed for stack ID collection in fetch_unique_stack_ids
# --- End Dependency Checks ---


# --- Configuration directly in the script ---
API_KEY_CONFIG=""                 # Your Immich API Key
API_URL_CONFIG=""                 # e.g., http://immich.yourdomain.com
DRY_RUN_CONFIG="true"             # Set to "false" to actually unstack

CURL_CONNECT_TIMEOUT_CONFIG="15" 
CURL_MAX_TIME_CONFIG="90"        

MAX_ASSETS_TO_SCAN_CONFIG="0" 
ASSET_TYPE_FILTER_UNSTACKER_CONFIG="IMAGE" # Filter for assets to scan for stacks
# --- End Configuration ---


# --- Helper Functions ---
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

# Process configuration variables
DRY_RUN=$(str_to_bool_val "$DRY_RUN_CONFIG")

API_KEY="$API_KEY_CONFIG"
API_URL="$API_URL_CONFIG"
CURL_CONNECT_TIMEOUT="$CURL_CONNECT_TIMEOUT_CONFIG"
CURL_MAX_TIME="$CURL_MAX_TIME_CONFIG"
ASSET_TYPE_FILTER_UNSTACKER="${ASSET_TYPE_FILTER_UNSTACKER_CONFIG}"


MAX_ASSETS_TO_SCAN=0 
if [[ "$MAX_ASSETS_TO_SCAN_CONFIG" =~ ^[0-9]+$ ]]; then 
    MAX_ASSETS_TO_SCAN="$MAX_ASSETS_TO_SCAN_CONFIG"
    if (( MAX_ASSETS_TO_SCAN > 0 )); then
        log_info "Maximum number of assets to scan (to check if they are stack covers) is set to $MAX_ASSETS_TO_SCAN."
    else
        log_info "MAX_ASSETS_TO_SCAN_CONFIG is 0, all fetched assets will be checked."
        MAX_ASSETS_TO_SCAN=0 
    fi
else
    log_info "Invalid value for MAX_ASSETS_TO_SCAN_CONFIG ('$MAX_ASSETS_TO_SCAN_CONFIG'), all fetched assets will be checked."
    MAX_ASSETS_TO_SCAN=0
fi

# --- Immich API Interaction Functions ---
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
  log_info "    curl: $method $full_url (Connect-Timeout: ${CURL_CONNECT_TIMEOUT}s, Max-Time: ${CURL_MAX_TIME}s)"
  
  if [ -n "$payload" ] && ( [ "$method" == "POST" ] || [ "$method" == "PUT" ] || [ "$method" == "DELETE" ] ); then
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
  if ([ "$method" == "DELETE" ] && [ "$endpoint" == "/stacks" ] && [ "$http_code" -eq 204 ]); then
      is_json_valid=true 
  elif ([ "$method" == "GET" ] && [[ "$endpoint" == "/stacks?primaryAssetId="* ]]); then
      if [ "$http_code" -eq 404 ]; then
          echo "NOT_A_STACK_COVER" 
          return 0 
      elif [ "$http_code" -eq 200 ] && echo "$response_body" | jq -e 'if type=="array" then true else false end' > /dev/null 2>&1; then
          is_json_valid=true
      elif ! echo "$response_body" | jq empty > /dev/null 2>&1; then 
          is_json_valid=false
          log_error "API response body for GET $endpoint is not valid JSON (HTTP $http_code)."
          log_error "Response body (shortened): $(echo "$response_body" | head -c 200)..."
      fi
  elif ! echo "$response_body" | jq empty > /dev/null 2>&1; then
      is_json_valid=false
      if ! [[ "$http_code" -ge 200 && "$http_code" -lt 300 && -z "$response_body" ]]; then 
        log_error "API response body is not valid JSON (HTTP $http_code): $method $full_url"
        log_error "API response body (shortened): $(echo "$response_body" | head -c 500)..."
      fi
  fi

  if [ "$method" == "DELETE" ] && [ "$endpoint" == "/stacks" ]; then
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
    if ! ([ "$method" == "GET" ] && [[ "$endpoint" == "/stacks?primaryAssetId="* ]] && [ "$http_code" -eq 404 ]); then
        log_error "API request failed (HTTP $http_code): $method $full_url"
        if ! $is_json_valid && [ -n "$response_body" ]; then
            : 
        elif [ -n "$response_body" ]; then 
            log_error "Response body: $response_body"
        fi
    fi
    return 1
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

fetch_unique_stack_ids() {
  local page_size=1000 current_page=1 total_assets_processed_for_stack_check=0
  local -a found_ids_array=() # Use a local array to store found IDs

  local last_api_next_page_value="" 
  local page_repeat_count=0
  local assets_scan_limit_reached=false

  log_info "Starting to fetch assets to check if they are stack covers (Type filter: ${ASSET_TYPE_FILTER_UNSTACKER:-ALL})..."
  log_info "    Page size for API requests (for asset list): $page_size"
  if (( MAX_ASSETS_TO_SCAN > 0 )); then
      log_info "    Limit: A maximum of $MAX_ASSETS_TO_SCAN assets will be checked as potential stack covers."
  fi

  while [ -n "$current_page" ]; do
    if $assets_scan_limit_reached && (( MAX_ASSETS_TO_SCAN > 0 )); then 
        log_info "    Asset scan limit of $MAX_ASSETS_TO_SCAN reached. Stopping further asset fetching."
        break
    fi

    local search_payload asset_list_response_json current_page_candidate assets_on_page_str
    
    local payload_jq_args=("--argjson" "size" "$page_size" "--argjson" "page" "$current_page" "--argjson" "withStacked" "true")
    if [ -n "$ASSET_TYPE_FILTER_UNSTACKER" ]; then
        payload_jq_args+=("--arg" "type" "$ASSET_TYPE_FILTER_UNSTACKER")
        search_payload=$(jq -n "${payload_jq_args[@]}" '{size: $size, page: $page, withStacked: $withStacked, type: $type}')
    else 
        search_payload=$(jq -n "${payload_jq_args[@]}" '{size: $size, page: $page, withStacked: $withStacked}')
    fi
    
    log_info "    Requesting asset list - Page: $current_page" 
    
    asset_list_response_json=$(immich_api_request "POST" "/search/metadata" "$search_payload")
    if [ $? -ne 0 ]; then 
        log_error "Critical error fetching asset list page $current_page. Aborting."
        return 1 
    fi

    current_page_candidate=$(echo "$asset_list_response_json" | jq -r '.assets.nextPage // empty' 2>/dev/null || echo "")
    if [ "$current_page_candidate" == "null" ]; then current_page_candidate=""; fi

    assets_on_page_str=$(echo "$asset_list_response_json" | jq -c '.assets.items[] // empty' 2>/dev/null || echo "")
    if [ -z "$assets_on_page_str" ]; then
        log_warn "    No assets found on page $current_page or error extracting items."
        current_page="$current_page_candidate"
        if [ -n "$current_page_candidate" ] && [ "$current_page_candidate" == "$last_api_next_page_value" ]; then
            page_repeat_count=$((page_repeat_count + 1)); if [ "$page_repeat_count" -gt 3 ]; then current_page=""; fi
        else page_repeat_count=0; fi
        last_api_next_page_value="$current_page_candidate";
        if [ -z "$current_page" ]; then log_info "    End of pagination reached (nextPage is empty)."; fi
        continue
    fi
    
    local single_asset_summary_json asset_id original_filename_debug stack_info_response stack_id_from_endpoint asset_type
    while IFS= read -r single_asset_summary_json; do
        if [ -z "$single_asset_summary_json" ]; then continue; fi

        total_assets_processed_for_stack_check=$((total_assets_processed_for_stack_check + 1))
        if (( MAX_ASSETS_TO_SCAN > 0 )) && (( total_assets_processed_for_stack_check > MAX_ASSETS_TO_SCAN )); then
            assets_scan_limit_reached=true; break
        fi
        
        asset_id=$(echo "$single_asset_summary_json" | jq -r '.id // empty')
        original_filename_debug=$(echo "$single_asset_summary_json" | jq -r '.originalFileName // "N/A"')
        asset_type=$(echo "$single_asset_summary_json" | jq -r '.type // "UNKNOWN"')


        if [ -z "$asset_id" ] || [ "$asset_id" == "null" ]; then
            log_warn "    Skipping asset with missing ID: $original_filename_debug"
            continue
        fi

        local extension; extension=$(get_file_extension "$original_filename_debug")
        if [[ "$extension" != "jpg" ]] && [[ "$extension" != "jpeg" ]]; then
            log_info "    ($total_assets_processed_for_stack_check) Skipping asset '$original_filename_debug' (not a JPG/JPEG) for stack cover check."
            continue
        fi

        log_info "    ($total_assets_processed_for_stack_check) Checking if JPG asset '$original_filename_debug' (ID: $asset_id) is a stack cover via GET /api/stacks?primaryAssetId=..."
        
        local api_call_status=0
        stack_info_response=$(immich_api_request "GET" "/stacks?primaryAssetId=${asset_id}" "") || api_call_status=$?
        
        if [ "$stack_info_response" == "NOT_A_STACK_COVER" ]; then
             log_info "      Asset '$original_filename_debug' is not a stack cover (API returned 404)."
        elif [ "$api_call_status" -eq 0 ] && [ -n "$stack_info_response" ]; then
            # Expecting response like: [{"id": "stack-uuid", "assets": [...]}] or []
            # If it's an array and the first element has an id, that's our stack ID
            stack_id_from_endpoint=$(echo "$stack_info_response" | jq -r '(if type=="array" and length > 0 then .[0].id else empty end) // empty' 2>/dev/null)

            if [ -n "$stack_id_from_endpoint" ] && [ "$stack_id_from_endpoint" != "null" ] && [ "$stack_id_from_endpoint" != "empty" ]; then
                log_info "      FOUND Stack ID: $stack_id_from_endpoint for asset '$original_filename_debug' (which is its cover)."
                found_ids_array+=("$stack_id_from_endpoint")
            else
                log_info "      Asset '$original_filename_debug' (ID: $asset_id) did not return a valid stack structure from /stacks endpoint."
                log_info "      Raw response from /stacks: $stack_info_response"
            fi
        else
            log_info "      Could not determine stack info for asset '$original_filename_debug' (GET /stacks returned error or unexpected empty response). API call status: $api_call_status"
        fi
    done <<< "$assets_on_page_str" 
    
    if $assets_scan_limit_reached && (( MAX_ASSETS_TO_SCAN > 0 )); then 
        current_page="" 
    else
        if [ -n "$current_page_candidate" ] && [ "$current_page_candidate" == "$last_api_next_page_value" ]; then
            page_repeat_count=$((page_repeat_count + 1))
            if [ "$page_repeat_count" -gt 3 ]; then current_page=""; fi
        else page_repeat_count=0; fi
        last_api_next_page_value="$current_page_candidate"; current_page="$current_page_candidate" 
    fi
    if [ -z "$current_page" ] && ! $assets_scan_limit_reached ; then log_info "    End of pagination reached."; fi
  done

  log_info "Asset scan for stack covers complete. $total_assets_processed_for_stack_check assets were checked."
  
  if [ ${#found_ids_array[@]} -gt 0 ]; then 
    printf "%s\n" "${found_ids_array[@]}" | sort -u
  else
    log_info "No stack IDs found by querying /api/stacks endpoint."
  fi
}

# --- Main Logic ---
main() {
  log_info "============== SCRIPT START: IMMICH UNSTACKER =============="
  if [ -z "$API_KEY_CONFIG" ]; then
    log_error "API_KEY_CONFIG is not set in the script. Please configure and try again. Exiting."
    exit 1
  fi
  log_info "API Key: [CONFIGURED]"
  log_info "API URL: $API_URL"
  log_info "DRY_RUN: $DRY_RUN_CONFIG (interpreted as: $DRY_RUN)"
  if (( MAX_ASSETS_TO_SCAN > 0 )); then # Corrected numeric comparison
      log_info "MAX ASSETS TO SCAN (Limit for finding stacks): $MAX_ASSETS_TO_SCAN"
  fi
  # DEBUG_CURL_COMMAND_CONFIG is used directly in immich_api_request

  # No global temp file for stack IDs needed anymore
  # trap '' EXIT # Clear any previous global trap if not needed

  if [ "$DRY_RUN" -eq "0" ]; then 
    log_warn "ATTENTION: Dry run (DRY_RUN) is enabled. NO changes will be made to your Immich library."
  else 
    log_info "Mode: Live run. Stacks will be unstacked."
  fi

  log_info "Step 1: Finding all unique stack IDs by scanning assets..."
  local unique_stack_ids_string
  unique_stack_ids_string=$(fetch_unique_stack_ids) 
  if [ $? -ne 0 ]; then 
      log_error "Error fetching assets to find stack IDs. Exiting."
      exit 1; 
  fi
  
  if [ -z "$unique_stack_ids_string" ]; then
      log_info "No stacks found. Nothing to unstack."
      log_info "============== SCRIPT END =============="; exit 0;
  fi

  mapfile -t unique_stack_ids_array < <(echo "$unique_stack_ids_string")

  if [ ${#unique_stack_ids_array[@]} -eq 0 ]; then
      log_info "No unique stack IDs found after filtering. Nothing to unstack."
      log_info "============== SCRIPT END =============="; exit 0;
  fi
  
  log_info "${#unique_stack_ids_array[@]} unique stack ID(s) found to be unstacked."

  local stacks_successfully_unstacked=0
  local stacks_failed_to_unstack=0 

  if [ "$DRY_RUN" -eq "0" ]; then
      log_warn "DRY RUN: Would attempt to unstack ${#unique_stack_ids_array[@]} stacks."
      log_warn "Affected Stack IDs (max. first 10): ${unique_stack_ids_array[*]:0:10} ..."
  else
      log_info "ACTION: Sending DELETE /api/stacks request to unstack ${#unique_stack_ids_array[@]} stacks..."
      
      local delete_payload_ids
      delete_payload_ids=$(printf '%s\n' "${unique_stack_ids_array[@]}" | jq -R . | jq -s .)
      
      local delete_payload
      delete_payload=$(jq -n --argjson ids "$delete_payload_ids" '{ids: $ids}')
      
      # Log payload only if curl commands are also logged (controlled by DEBUG_CURL_COMMAND)
      if [ "$DEBUG_CURL_COMMAND" -eq 0 ]; then 
          log_info "    Payload for DELETE /api/stacks: $delete_payload"
      fi

      if immich_api_request "DELETE" "/stacks" "$delete_payload"; then
          log_info "    API call to unstack was successful (HTTP 204)."
          stacks_successfully_unstacked=${#unique_stack_ids_array[@]} 
      else
          log_error "    ERROR in API call to unstack!"
          stacks_failed_to_unstack=${#unique_stack_ids_array[@]} 
      fi
  fi

  log_info "Unstacking process complete."
  if [ "$DRY_RUN" -ne "0" ]; then # Only log counts if not a dry run
    log_info "    $stacks_successfully_unstacked stacks successfully unstacked."
    if [ "$stacks_failed_to_unstack" -gt 0 ]; then
        log_info "    $stacks_failed_to_unstack stacks could not be unstacked (see API error above)."
    fi
  fi
  log_info "============== SCRIPT END =============="
}

main
