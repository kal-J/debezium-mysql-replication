#!/bin/bash

# Load environment variables
source .env

echo "Recovery script - Restarting replication from saved binlog position..."

# Check if binlog-position.txt exists
if [ ! -f "binlog-position.txt" ]; then
    echo "ERROR: binlog-position.txt not found!"
    echo "Please run the initial data sync or update the binlog position first."
    exit 1
fi

# Load the saved binlog position
source binlog-position.txt

echo "Recovery position: $BINLOG_FILE:$BINLOG_POS"

# Verify the position is still valid on the source
echo "Verifying binlog position on source server..."
BINLOG_INFO=$(mysql --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  -e "SHOW MASTER STATUS\G" | grep -E 'File:|Position:')

CURRENT_FILE=$(echo "$BINLOG_INFO" | grep 'File:' | awk '{print $2}')
CURRENT_POS=$(echo "$BINLOG_INFO" | grep 'Position:' | awk '{print $2}')

echo "Current source position: $CURRENT_FILE:$CURRENT_POS"

# Check if the saved position is still available
if [ "$BINLOG_FILE" != "$CURRENT_FILE" ]; then
    echo "WARNING: The saved binlog file ($BINLOG_FILE) is different from the current file ($CURRENT_FILE)"
    echo "This might indicate that the binlog has rotated since the last update."
    echo "You may need to update the binlog position or perform a fresh initial sync."
fi

# Stop existing connectors if they exist
echo "Stopping existing connectors..."
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-source-connector 2>/dev/null || true
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-sink-connector 2>/dev/null || true

# Wait a moment for connectors to stop
sleep 5

# Restart the connectors using the saved position
echo "Restarting source connector with saved position..."
./create-source-connector.sh

echo "Restarting sink connector..."
./create-sink-connector.sh

echo "Recovery completed!"
echo "Connectors have been restarted using position: $BINLOG_FILE:$BINLOG_POS"
echo "Monitor the replication status with:"
echo "  curl -X GET http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-source-connector/status"
echo "  curl -X GET http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-sink-connector/status" 