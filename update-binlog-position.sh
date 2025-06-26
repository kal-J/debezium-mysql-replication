#!/bin/bash

# Load environment variables
source .env

echo "Updating binlog position from source MySQL server..."

# Get the current binary log file and position from the source
BINLOG_INFO=$(mysql --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  -e "SHOW MASTER STATUS\G" | grep -E 'File:|Position:')

BINLOG_FILE=$(echo "$BINLOG_INFO" | grep 'File:' | awk '{print $2}')
BINLOG_POS=$(echo "$BINLOG_INFO" | grep 'Position:' | awk '{print $2}')

echo "Current binary log file: $BINLOG_FILE"
echo "Current binary log position: $BINLOG_POS"

# Save this information to the file
cat > ./binlog-position.txt << EOF
BINLOG_FILE=$BINLOG_FILE
BINLOG_POS=$BINLOG_POS
EOF

echo "Binlog position updated successfully!"
echo "File: $BINLOG_FILE"
echo "Position: $BINLOG_POS" 