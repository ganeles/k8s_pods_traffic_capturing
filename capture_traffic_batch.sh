#!/bin/bash

# --- Parse arguments ---
show_help() {
  echo "Usage: $0 -n <namespace> -p <pod_prefix> -d <duration_minutes>"
  echo
  echo "  -n     Kubernetes namespace (required)"
  echo "  -p     Pod name prefix (required)"
  echo "  -d     Tcpdump duration in minutes (required)"
  echo
  echo "Example:"
  echo "  $0 -n glip-ha-lab -p gas -d 10"
  echo
  echo "Don't forget: you need to be authenticated in advance to run kubectl against your env"
  exit 1
}

while getopts ":n:p:d:" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    p) POD_PREFIX="$OPTARG" ;;
    d) TCPDUMP_DURATION_MINUTES="$OPTARG" ;;	
    *) show_help ;;
  esac
done

# --- Validate inputs ---
if [ -z "$NAMESPACE" ] || [ -z "$POD_PREFIX" ] || [ -z "$TCPDUMP_DURATION_MINUTES" ]; then
  show_help
fi

# Configuration
TCPDUMP_DURATION=$((TCPDUMP_DURATION_MINUTES * 60))       # in seconds
HOLD_DURATION=$((TCPDUMP_DURATION * 10))                   # time to keep container alive
IMAGE="nicolaka/netshoot"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H-%M-%SZ')
OUTPUT_DIR="./pcaps_${POD_PREFIX}-${TIMESTAMP}"
LOG_FILE="$OUTPUT_DIR/pcap-dump.log"
TCPDUMP_CMD_TEMPLATE='tcpdump -i any -w "{PCAP_PATH}" -G {DURATION} -W 1'

mkdir -p "$OUTPUT_DIR"
echo "=== Script started at: $(date -u) ===" > "$LOG_FILE"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

get_target_container() {
  local pod=$1
  kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].name}'
}

get_ephemeral_container() {
  local pod=$1
  kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.spec.ephemeralContainers[-1:].name}"
}

process_pod() {
  local pod=$1
  log "[$pod] Starting processing..."

  local target_container
  target_container=$(get_target_container "$pod")
  if [ -z "$target_container" ]; then
    log "[$pod] Could not find main container. Skipping."
    return
  fi
  log "[$pod] Main container: $target_container"

  local remote_pcap_path="/tmp/${pod}.pcap"

  # Prepare tcpdump command
  local tcpdump_cmd=${TCPDUMP_CMD_TEMPLATE//\{PCAP_PATH\}/$remote_pcap_path}
  tcpdump_cmd=${tcpdump_cmd//\{DURATION\}/$TCPDUMP_DURATION}
  tcpdump_cmd="$tcpdump_cmd && sleep $HOLD_DURATION"

  log "[$pod] Launching ephemeral container..."
  kubectl -n "$NAMESPACE" debug "$pod" \
    --image="$IMAGE" \
    --target="$target_container" \
    -- sh -c "$tcpdump_cmd" &

  local debug_pid=$!

  log "[$pod] Waiting $TCPDUMP_DURATION + 60 seconds for capture..."
  sleep "$TCPDUMP_DURATION"
  sleep 60

  local sidecar=""
  for attempt in {1..10}; do
    sidecar=$(get_ephemeral_container "$pod")
    if [ -n "$sidecar" ]; then
      break
    fi
    log "[$pod] Waiting for ephemeral container (attempt $attempt)..."
    sleep 3
  done

  if [ -z "$sidecar" ]; then
    log "[$pod] Ephemeral container not found. Skipping file copy."
    return
  fi

  log "[$pod] Ephemeral container: $sidecar"

  # Copy with cat
  log "[$pod] Copying $remote_pcap_path using cat..."
  if kubectl -n "$NAMESPACE" exec -c "$sidecar" "$pod" -- \
      cat "$remote_pcap_path" > "${OUTPUT_DIR}/${pod}.pcap"; then
    log "[$pod] File saved as ${OUTPUT_DIR}/${pod}.pcap"
  else
    log "[$pod] Failed to copy the file."
  fi

  # Kill sleep
  log "[$pod] Killing sleep process..."
  kubectl -n "$NAMESPACE" exec -c "$sidecar" "$pod" -- \
    pkill -f "sleep $HOLD_DURATION"

  wait "$debug_pid"
  log "[$pod] Done."
}

# Get matching pods
pods=$(kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" | grep "^$POD_PREFIX")

if [ -z "$pods" ]; then
  log "No pods found with prefix '$POD_PREFIX'"
  exit 1
fi

for pod in $pods; do
  process_pod "$pod" &
done

wait
log "All done."