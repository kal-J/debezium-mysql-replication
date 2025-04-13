#!/bin/bash

# Load environment variables
source .env

# Remove mysql-sink-connector-config.json if it exists
if [ -f "mysql-sink-connector-config.json" ]; then
    rm mysql-sink-connector-config.json
fi

# Define topics regex pattern based on tables to exclude
TOPICS_REGEX="mysql-server-a\\\\.SOURCE_DATABASE\\\\..*"
if [ -n "$TABLES_TO_EXCLUDE" ]; then
    TOPICS_REGEX="mysql-server-a\\\\.SOURCE_DATABASE\\\\.((?!${TABLES_TO_EXCLUDE}).)*"
fi

# Create the connector JSON configuration using environment variables
cat > mysql-sink-connector-config.json << EOF
{
  "name": "mysql-sink-connector",
  "config": {
    "connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "topics.regex": "${TOPICS_REGEX}",
    "connection.url": "jdbc:mysql://DEST_MYSQL_HOST:DEST_MYSQL_PORT/DEST_MYSQL_DATABASE",
    "connection.username": "DEST_MYSQL_USER",
    "connection.password": "DEST_MYSQL_PASSWORD",
    "insert.mode": "upsert",
    "delete.enabled": "true",
    "primary.key.mode": "record_key",
    "schema.evolution": "basic",
    "table.name.format": "\${topic}",
    "tombstones.behavior": "delete",
    "database.timezone": "UTC",
    "database.dialect": "mysql",
    "transforms": "route,dropDeleted",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "mysql-server-a.SOURCE_DATABASE.(.*)",
    "transforms.route.replacement": "\$1",
    "transforms.dropDeleted.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
    "transforms.dropDeleted.blacklist": "__deleted",
    "errors.tolerance": "all",
    "errors.retry.timeout": "60000",
    "errors.retry.delay.max.ms": "5000",
    "errors.deadletterqueue.topic.name": "dlq-mysql-sink",
    "errors.deadletterqueue.topic.replication.factor": 1,
    "errors.log.include.messages": "true",
    "errors.log.enable": "true",
    "auto.evolve.allow.non.nullable": "true",
    "quote.identifiers": "true"
  }
}
EOF

# Replace placeholders with actual values
sed -i "s/SOURCE_DATABASE/${SOURCE_MYSQL_DATABASE}/g" mysql-sink-connector-config.json
sed -i "s/DEST_MYSQL_HOST/${DEST_MYSQL_HOST}/g" mysql-sink-connector-config.json
sed -i "s/DEST_MYSQL_PORT/${DEST_MYSQL_PORT}/g" mysql-sink-connector-config.json
sed -i "s/DEST_MYSQL_DATABASE/${DEST_MYSQL_DATABASE}/g" mysql-sink-connector-config.json
sed -i "s/DEST_MYSQL_USER/${DEST_MYSQL_USER}/g" mysql-sink-connector-config.json
sed -i "s/DEST_MYSQL_PASSWORD/${DEST_MYSQL_PASSWORD}/g" mysql-sink-connector-config.json

# Deploy the connector
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-sink-connector 2>/dev/null || true
sleep 2
curl -X POST -H "Content-Type: application/json" --data @mysql-sink-connector-config.json http://localhost:${KAFKA_CONNECT_PORT}/connectors

echo "Sink connector deployed with table exclusions: ${TABLES_TO_EXCLUDE}"

# Optional: Print the actual regex used for verification
echo "Topics regex pattern used: ${TOPICS_REGEX}"