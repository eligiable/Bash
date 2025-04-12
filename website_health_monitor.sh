#!/bin/bash

###############################################################################
# Description: Monitors website availability and manages MySQL sleep connections when the site is down. Sends email notifications for status changes.
#
# Requirements:
# - curl for website checking
# - mysql client for database operations
# - mailx or similar for email notifications
#
# Configuration:
# - Edit variables in the "User Configurable Settings" section below
#
# Logs:
# - /tmp/isUpDown.log - Contains detailed status information
###############################################################################

### User Configurable Settings ###
WEBSITE_URL="https://example.com"       # Website URL to monitor
SLEEP_TIME="15"                         # Minimum sleep time (seconds) for MySQL connections to consider killing
MAX_CONNECTIONS="50"                    # Maximum allowed sleep connections before taking action
MYSQL_HOST="100.121.31.99"              # MySQL server host
MYSQL_USER="root"                       # MySQL username
MYSQL_PASS="1q2w3e4r5t_"               # MySQL password
EMAIL_RECIPIENT="it-support@example.com" # Email notification recipient
FROM_EMAIL="Example TV<no-reply@example.com>" # Sender email for notifications
LOG_FILE="/tmp/isUpDown.log"            # Path to log file
TEMP_FILE="/tmp/isUpDown.txt"           # Path to temporary file

### Main Script ###

# Clear previous log file
> "$LOG_FILE"

# Check website availability
if curl -s --insecure --head --request GET "$WEBSITE_URL" | grep "200\|301\|302" > /dev/null 2>&1; then
    echo "$(date) - $WEBSITE_URL is UP" >> "$LOG_FILE"
else
    echo "$(date) - $WEBSITE_URL is DOWN" >> "$LOG_FILE"
    echo "Sleep Time = $SLEEP_TIME" >> "$LOG_FILE"
    echo "Max Allowed Connections = $MAX_CONNECTIONS" >> "$LOG_FILE"

    # Get total sleep connections
    TOTAL_SLEEPS=$(mysql -B --column-names=0 -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT COUNT(*) FROM information_schema.processlist WHERE COMMAND = 'Sleep' AND TIME >= '$SLEEP_TIME';" 2>> "$LOG_FILE")
    
    echo "Total Sleep Connections = $TOTAL_SLEEPS" >> "$LOG_FILE"

    if [ "$TOTAL_SLEEPS" -le "$MAX_CONNECTIONS" ]; then
        # If sleep connections are below threshold, just send notification
        mail -s "URGENT Notification | $WEBSITE_URL is Down" "$EMAIL_RECIPIENT" < "$LOG_FILE" -a "From:$FROM_EMAIL" > /dev/null 2>&1
    else
        # If sleep connections exceed threshold, take corrective action
        echo "$(date) - Taking corrective action (restarting PHP-FPM)" >> "$LOG_FILE"
        
        # Generate kill commands for sleep connections (commented out by default)
        # mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT CONCAT('KILL ',ID,';') FROM information_schema.processlist WHERE COMMAND = 'Sleep' AND TIME >= '$SLEEP_TIME'" > "$TEMP_FILE" 2>> "$LOG_FILE"
        # sed -i "/CONCAT('KILL ',ID,';')/d" "$TEMP_FILE"
        # mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "source $TEMP_FILE" 2>> "$LOG_FILE"
        
        # Restart PHP-FPM
        service php7.0-fpm restart >> "$LOG_FILE" 2>&1
        
        # Send notification with action taken
        mail -s "Corrective Action Taken | $WEBSITE_URL was Down" "$EMAIL_RECIPIENT" < "$LOG_FILE" -a "From:$FROM_EMAIL" > /dev/null 2>&1
    fi
fi