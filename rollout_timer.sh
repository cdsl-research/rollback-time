#!/bin/bash

# ===============================
# Rollback Time Tracker
# ===============================

# List of [namespace deployment]
DEPLOYMENTS=(
  "author author-app-deploy"
  "paper paper-app-deploy"
  "stats stats-app-deploy"
  "front front-app-deploy"
  "front-admin front-admin-app-deploy"
  "thumbnail thumbnail-app-deploy"
  "fulltext fulltext-app-deploy"
)

LOG_DIR="rollout-logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/rollout_parallel_log_$TIMESTAMP.txt"
TMP_LOG_DIR="$LOG_DIR/tmp_$TIMESTAMP"
mkdir -p "$TMP_LOG_DIR"

echo "Starting parallel rollout tracking at $(date)" | tee "$LOG_FILE"

TOTAL_START=$(date +%s)

# Function to monitor a single deployment
monitor_rollout() {
  NS=$1
  DEP=$2
  TMP_FILE="$TMP_LOG_DIR/${NS}_${DEP}.log"

  START_TIME=$(date +%s)
  echo "[${NS}/${DEP}] Start: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TMP_FILE"

  kubectl rollout status deployment/"$DEP" -n "$NS" >> "$TMP_FILE" 2>&1

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo "[${NS}/${DEP}] End:   $(date '+%Y-%m-%d %H:%M:%S')" >> "$TMP_FILE"
  echo "[${NS}/${DEP}] Duration: ${DURATION} seconds" >> "$TMP_FILE"
}

# Launch all monitors in background
for entry in "${DEPLOYMENTS[@]}"; do
  NS=$(echo $entry | awk '{print $1}')
  DEP=$(echo $entry | awk '{print $2}')
  monitor_rollout "$NS" "$DEP" &
done

# Wait for all background jobs to finish
wait

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

# Consolidate logs
echo -e "\n Rollout Summary:" >> "$LOG_FILE"
for entry in "${DEPLOYMENTS[@]}"; do
  NS=$(echo $entry | awk '{print $1}')
  DEP=$(echo $entry | awk '{print $2}')
  echo "----------------------------------------" >> "$LOG_FILE"
  cat "$TMP_LOG_DIR/${NS}_${DEP}.log" >> "$LOG_FILE"
done

echo -e "\n All rollouts completed at $(date)" >> "$LOG_FILE"
echo "Total parallel rollout time: ${TOTAL_DURATION} seconds" >> "$LOG_FILE"

# Clean up temp logs
rm -rf "$TMP_LOG_DIR"
