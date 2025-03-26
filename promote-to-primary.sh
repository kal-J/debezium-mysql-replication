#!/bin/bash

# Load environment variables
source .env

echo "Starting promotion of destination database to primary..."

# First, stop the Debezium connectors to prevent further replication
echo "Stopping replication connectors..."
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-source-connector
curl -X DELETE http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-sink-connector

echo "Replication stopped."

# Import the complete schema with triggers and events
echo "Activating triggers and events on the destination database..."

# Check if the latest schema sync is available
if [ -d "./ready_for_promotion/latest" ]; then
    SCHEMA_FILE="./ready_for_promotion/latest/complete_schema.sql"
    echo "Using the latest schema sync: ${SCHEMA_FILE}"
elif [ -f "./ready_for_promotion/schema_with_triggers_events.sql" ]; then
    SCHEMA_FILE="./ready_for_promotion/schema_with_triggers_events.sql"
    echo "Using the initial schema: ${SCHEMA_FILE}"
else
    echo "Error: No schema file found. Make sure you ran the initial-data-sync.sh or schema-sync.sh script."
    exit 1
fi

# First, drop existing routines, triggers, and events to avoid conflicts
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  -e "
    USE ${DEST_MYSQL_DATABASE};
    
    -- Get and drop all triggers
    SELECT CONCAT('DROP TRIGGER IF EXISTS ', TRIGGER_NAME, ';') 
    FROM information_schema.TRIGGERS 
    WHERE TRIGGER_SCHEMA = '${DEST_MYSQL_DATABASE}'
    INTO OUTFILE '/tmp/drop_triggers.sql';
    
    -- Get and drop all events
    SELECT CONCAT('DROP EVENT IF EXISTS ', EVENT_NAME, ';')
    FROM information_schema.EVENTS 
    WHERE EVENT_SCHEMA = '${DEST_MYSQL_DATABASE}'
    INTO OUTFILE '/tmp/drop_events.sql';
    
    -- Get and drop all routines (procedures and functions)
    SELECT CONCAT('DROP ', ROUTINE_TYPE, ' IF EXISTS ', ROUTINE_NAME, ';')
    FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = '${DEST_MYSQL_DATABASE}'
    INTO OUTFILE '/tmp/drop_routines.sql';
  "

# Execute the drop scripts
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < /tmp/drop_triggers.sql

mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < /tmp/drop_events.sql

mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < /tmp/drop_routines.sql

# Now import the complete schema with triggers and events
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < ${SCHEMA_FILE}

# Enable event scheduler on destination MySQL server if needed
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  -e "SET GLOBAL event_scheduler = ON;"

echo "Triggers and events have been activated on the destination database."
echo "The destination database is now ready to be used as the primary database."
echo "Promotion complete!"