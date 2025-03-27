#!/bin/bash

# Load environment variables
source .env

# Check if binlog-position.txt exists and use it for the connector configuration
if [ -f "binlog-position.txt" ]; then
  source binlog-position.txt
  echo "Using binary log position from file: $BINLOG_FILE:$BINLOG_POS"
  SNAPSHOT_MODE="schema_only"
  BINLOG_CONFIG=",\"database.history.kafka.recovery.poll.interval.ms\": \"5000\", \"snapshot.mode\": \"${SNAPSHOT_MODE}\", \"snapshot.locking.mode\": \"none\""
  
  # If the binlog file and position are available, add them to the configuration
  if [ ! -z "$BINLOG_FILE" ] && [ ! -z "$BINLOG_POS" ]; then
    BINLOG_CONFIG="$BINLOG_CONFIG, \"database.history.kafka.recovery.attempts\": \"10\", \"database.bin.log.filename\": \"${BINLOG_FILE}\", \"database.bin.log.position\": \"${BINLOG_POS}\""
  fi
else
  echo "No binlog position file found. Will use default snapshot mode."
  SNAPSHOT_MODE="initial"
  BINLOG_CONFIG=", \"snapshot.mode\": \"${SNAPSHOT_MODE}\""
fi

# Remove mysql-source-connector-config.json if it exists
if [ -f "mysql-source-connector-config.json" ]; then
  rm mysql-source-connector-config.json
fi

# Create the connector JSON configuration using environment variables
cat > mysql-source-connector-config.json << EOF
{
  "name": "mysql-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "${SOURCE_MYSQL_HOST}",
    "database.port": "${SOURCE_MYSQL_PORT}",
    "database.user": "${SOURCE_MYSQL_USER}",
    "database.password": "${SOURCE_MYSQL_PASSWORD}",
    "database.server.id": "1",
    "database.server.name": "mysql-server-a",
    "database.include": "${SOURCE_MYSQL_DATABASE}",
    "topic.prefix": "mysql-server-a",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "schema-changes.mysql",
    "include.schema.changes": "true",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.delete.handling.mode": "rewrite",
    "time.precision.mode": "connect"${BINLOG_CONFIG}
  }
}
EOF

# Deploy the connector
curl -X POST -H "Content-Type: application/json" --data @mysql-source-connector-config.json http://localhost:${KAFKA_CONNECT_PORT}/connectors

echo "Source connector deployed"