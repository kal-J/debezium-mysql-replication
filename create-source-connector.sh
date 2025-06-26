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
    "topic.prefix": "mysql-server-a",
    "database.include.list": "${SOURCE_MYSQL_DATABASE}",
    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-changes.mysql",
    "schema.history.internal.consumer.security.protocol": "PLAINTEXT",
    "schema.history.internal.producer.security.protocol": "PLAINTEXT",
    "include.schema.changes": "true",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.delete.handling.mode": "rewrite",
    "time.precision.mode": "connect"${BINLOG_CONFIG},
    "producer.override.max.request.size": "9097152"
  }
}
EOF

# Deploy the connector
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-source-connector 2>/dev/null || true
curl -X POST -H "Content-Type: application/json" --data @mysql-source-connector-config.json http://localhost:${KAFKA_CONNECT_PORT}/connectors

echo "Source connector deployed"