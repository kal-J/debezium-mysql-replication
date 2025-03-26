#!/bin/bash

# Load environment variables
source .env

# Remove mysql-sink-connector-config.json if it exists
if [ -f "mysql-sink-connector-config.json" ]; then
    rm mysql-sink-connector-config.json
fi

# Create the connector JSON configuration using environment variables
cat > mysql-sink-connector-config.json << EOF
{
  "name": "mysql-sink-connector",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "topics.regex": "mysql-server-a\\.${SOURCE_MYSQL_DATABASE}\\.[^\\.].*",
    "connection.url": "jdbc:mysql://${DEST_MYSQL_HOST}:${DEST_MYSQL_PORT}/${DEST_MYSQL_DATABASE}",
    "connection.user": "${DEST_MYSQL_USER}",
    "connection.password": "${DEST_MYSQL_PASSWORD}",
    "auto.create": "true",
    "auto.evolve": "true",
    "insert.mode": "upsert",
    "delete.enabled": "true",
    "pk.mode": "record_key",
    "pk.fields": "id",
    "transforms": "unwrap,route",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
    "transforms.route.replacement": "\$3"
  }
}
EOF

# Deploy the connector
curl -X POST -H "Content-Type: application/json" --data @mysql-sink-connector-config.json http://localhost:${KAFKA_CONNECT_PORT}/connectors

echo "Sink connector deployed"