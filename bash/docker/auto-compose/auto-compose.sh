#!/bin/bash

# --- CHECK PREREQUISITES ---
if ! command -v jq &> /dev/null
then
	echo "ERROR: The 'jq' command-line tool is required for this script, but was not found."
	echo "Please install it using 'sudo apt install jq' or 'sudo yum install jq'."
	exit 1
fi

# --- VARIABLES ---
OUTPUT_DIR="docker_compose_files_native"
mkdir -p "$OUTPUT_DIR"

# --- MAIN PROGRAM ---
echo "Searching for running Docker containers..."
CONTAINER_IDS=$(docker ps -q)

if [ -z "$CONTAINER_IDS" ]; then
	echo "No running Docker containers found."
	exit 0
fi

echo "Generating Docker Compose files for the following containers:"
echo "----------------------------------------------------"
docker ps --format "table {{.ID}}\t{{.Names}}"
echo "----------------------------------------------------"

# Iterate over each container
for CONTAINER_ID in $CONTAINER_IDS
do
	# Get the complete inspection data once as JSON
	INSPECT_JSON=$(docker inspect "$CONTAINER_ID")

	# Extract the container name and sanitize it for filenames and service names
	CONTAINER_NAME=$(echo "$INSPECT_JSON" | jq -r '.[0].Name' | sed 's:^/::')
	SERVICE_NAME=$(echo "$CONTAINER_NAME" | tr -cd '[:alnum:]_-')
	OUTPUT_FILE="${OUTPUT_DIR}/${CONTAINER_NAME}-compose.yml"

	# Extract network info once, to be used in both service and top-level definitions
	NETWORKS_JSON=$(echo "$INSPECT_JSON" | jq -c '.[0].NetworkSettings.Networks | to_entries')

	echo "Processing container: ${CONTAINER_NAME} (${CONTAINER_ID})"

	# --- START YAML GENERATION (SINGLE ATOMIC BLOCK) ---
	{
		# Header
		echo "version: '3.8'"
		echo "services:"
		echo "  ${SERVICE_NAME}:"

		# Image
		IMAGE=$(echo "$INSPECT_JSON" | jq -r '.[0].Config.Image')
		echo "    image: ${IMAGE}"

		# Container Name
		echo "    container_name: ${CONTAINER_NAME}"

		# Restart Policy
		RESTART_POLICY=$(echo "$INSPECT_JSON" | jq -r '.[0].HostConfig.RestartPolicy.Name')
		if [ -n "$RESTART_POLICY" ] && [ "$RESTART_POLICY" != "no" ]; then
			echo "    restart: ${RESTART_POLICY}"
		fi

		# Ports
		PORTS=$(echo "$INSPECT_JSON" | jq -r '.[0].HostConfig.PortBindings | to_entries | .[] | select(.value != null) | .value[0].HostPort + ":" + .key')
		if [ -n "$PORTS" ]; then
			echo "    ports:"
			while IFS= read -r port; do
				echo "      - \"${port}\""
			done <<< "$PORTS"
		fi

		# Environment Variables
		# Filter out common injected variables like PATH, HOSTNAME, HOME etc.
		ENVS=$(echo "$INSPECT_JSON" | jq -r '.[0].Config.Env | .[]?' | grep -vE '^(PATH|Path|HOSTNAME|HOME)=')
		if [ -n "$ENVS" ]; then
			echo "    environment:"
			while IFS= read -r env; do
				echo "      - \"${env}\""
			done <<< "$ENVS"
		fi

		# Volumes / Mounts
		MOUNTS=$(echo "$INSPECT_JSON" | jq -r '.[0].Mounts | .[]? | .Source + ":" + .Destination + if .RW == false then ":ro" else "" end')
		if [ -n "$MOUNTS" ]; then
			echo "    volumes:"
			while IFS= read -r mount; do
				echo "      - \"${mount}\""
			done <<< "$MOUNTS"
		fi
		
		# Command
		COMMAND=$(echo "$INSPECT_JSON" | jq -r '.[0].Config.Cmd | if . == null then "" else tojson end')
		if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ] && [ "$COMMAND" != "[]" ]; then
			echo "    command: ${COMMAND}"
		fi

		# Networks with static IP address
		if [ -n "$NETWORKS_JSON" ] && [ "$NETWORKS_JSON" != "[]" ]; then
			echo "    networks:"
			echo "$NETWORKS_JSON" | jq -r '.[] | @base64' | while IFS= read -r item; do
				_jq() {
					echo "${item}" | base64 --decode | jq -r "${1}"
				}
				
				NET_NAME=$(_jq '.key')
				IP_ADDRESS=$(_jq '.value.IPAddress')

				echo "      ${NET_NAME}:"
				# Only assign an IP if it exists (prevents empty entries)
				if [ -n "$IP_ADDRESS" ]; then
					echo "        ipv4_address: ${IP_ADDRESS}"
				fi
			done
		fi
		
		# --- MOVED BLOCK ---
		# Top-level networks configuration
		if [ -n "$NETWORKS_JSON" ] && [ "$NETWORKS_JSON" != "[]" ]; then
			echo ""
			echo "networks:"
			
			# Get a simple newline-separated list of network names
			NET_NAMES=$(echo "$NETWORKS_JSON" | jq -r '.[].key')
			
			# Loop over the extracted network names
			# Use a here-string (<<<) to safely feed the loop
			while IFS= read -r NET_NAME; do
				if [ -n "$NET_NAME" ]; then
					# Declare the network as external, as requested by the user
					echo "  ${NET_NAME}:"
					echo "    external: true"
				fi
			done <<< "$NET_NAMES"
		fi
		
	} > "$OUTPUT_FILE" # --- END YAML GENERATION (SINGLE ATOMIC BLOCK) ---


	if [ $? -eq 0 ]; then
		echo "-> Successfully created '${OUTPUT_FILE}'."
	else
		echo "-> ERROR creating compose file for ${CONTAINER_NAME}."
	fi

done

echo "----------------------------------------------------"
echo "Script finished. All files saved to '${OUTPUT_DIR}' directory."