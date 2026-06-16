#!/usr/bin/env bash
# Pre-class load generator — run 30 minutes before the session.
# Sends HTTP traffic to the ALB to populate CloudWatch metrics for the dashboard demo.
#
# Usage: ./load-gen.sh
# Stop with Ctrl+C

ALB_URL="http://REPLACE_WITH_YOUR_ALB_DNS_NAME"

ENDPOINTS=("/" "/health" "/error")
SLEEP_SECONDS=2

echo "Sending traffic to ${ALB_URL}"
echo "Ctrl+C to stop"
echo ""

count=0
while true; do
  endpoint=${ENDPOINTS[$((count % ${#ENDPOINTS[@]}))]}
  url="${ALB_URL}${endpoint}"
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${url}")
  echo "$(date '+%H:%M:%S')  ${endpoint}  →  HTTP ${status}"
  count=$((count + 1))
  sleep "${SLEEP_SECONDS}"
done
