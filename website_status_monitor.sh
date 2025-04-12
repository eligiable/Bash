#!/bin/bash

# Description: This script checks if a website is online by attempting to access it multiple times. It verifies the HTTP status code and provides appropriate exit codes for monitoring systems.
# Usage: ./website_status_monitor.sh [URL] [ATTEMPTS] [TIMEOUT]
# Default values will be used if no arguments are provided.

# Set default values
url=${1:-'https://www.example.com'}
attempts=${2:-5}
timeout=${3:-5}
online=false

echo "Website Status Monitor"
echo "Checking status of: $url"
echo "Maximum attempts: $attempts"
echo "Timeout between attempts: ${timeout}s"
echo "----------------------------------------"

for (( i=1; i<=$attempts; i++ ))
do
  echo "Attempt $i of $attempts..."
  
  # Curl command with:
  # -s: silent mode
  # -L: follow redirects
  # --connect-timeout: timeout for connection establishment
  # --max-time: maximum time for the whole operation
  # -w: write HTTP status code
  # -o: redirect output to /dev/null
  code=$(curl -sL --connect-timeout $timeout --max-time 15 -w "%{http_code}\\n" "$url" -o /dev/null)

  echo "HTTP Status Code: $code"
  
  # Check for successful response (200-399 are generally considered successful)
  if [[ "$code" =~ ^2[0-9]{2}$ || "$code" =~ ^3[0-9]{2}$ ]]; then
    echo "SUCCESS: Website $url is online (HTTP $code)."
    online=true
    break
  else
    echo "WARNING: Website may be offline or experiencing issues (HTTP $code)."
    
    # Only wait if there are more attempts remaining
    if [ $i -lt $attempts ]; then
      echo "Waiting $timeout seconds before next attempt..."
      sleep $timeout
    fi
  fi
done

# Final status and exit code
if $online; then
  echo "----------------------------------------"
  echo "MONITOR RESULT: Website is online."
  exit 0
else
  echo "----------------------------------------"
  echo "MONITOR RESULT: Website is down after $attempts attempts."
  exit 1
fi