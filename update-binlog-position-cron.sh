#!/bin/bash

# Load environment variables
source .env

# Set up logging
LOG_FILE="./binlog-position-update.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting binlog position update..." >> $LOG_FILE

# Get the current binary log file and position from the source
BINLOG_INFO=$(mysql --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  -e "SHOW MASTER STATUS\G" 2>/dev/null | grep -E 'File:|Position:')

if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] ERROR: Failed to connect to source MySQL server" >> $LOG_FILE
    exit 1
fi

BINLOG_FILE=$(echo "$BINLOG_INFO" | grep 'File:' | awk '{print $2}')
BINLOG_POS=$(echo "$BINLOG_INFO" | grep 'Position:' | awk '{print $2}')

# Validate that we got valid values
if [ -z "$BINLOG_FILE" ] || [ -z "$BINLOG_POS" ]; then
    echo "[$TIMESTAMP] ERROR: Failed to extract binlog information" >> $LOG_FILE
    exit 1
fi

# Save this information to the file
cat > ./binlog-position.txt << EOF
BINLOG_FILE=$BINLOG_FILE
BINLOG_POS=$BINLOG_POS
EOF

echo "[$TIMESTAMP] Binlog position updated successfully - File: $BINLOG_FILE, Position: $BINLOG_POS" >> $LOG_FILE

# Keep only the last 1000 lines of the log file to prevent it from growing too large
tail -n 1000 $LOG_FILE > $LOG_FILE.tmp && mv $LOG_FILE.tmp $LOG_FILE 