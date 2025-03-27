#!/bin/bash

# Load environment variables
source .env

# Make sure the MySQL client tools are installed
# On Debian/Ubuntu: apt-get install -y mysql-client
# On RHEL/CentOS: yum install -y mysql

echo "Starting initial data dump from source database..."

# Create a directory for the dump if it doesn't exist
mkdir -p ./dump

# Dump the database schema including routines, events, and triggers
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --routines \
  --events \
  --triggers \
  ${SOURCE_MYSQL_DATABASE} > ./dump/schema_with_triggers_events.sql

# Also dump a clean schema without triggers for normal use
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --routines \
  --skip-triggers \
  --skip-events \
  ${SOURCE_MYSQL_DATABASE} > ./dump/schema.sql

echo "Schema dump completed."

# Dump the data without the schema
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-create-info \
  --skip-triggers \
  --extended-insert \
  --complete-insert \
  --disable-keys \
  --quick \
  --compression-algorithms \
  ${SOURCE_MYSQL_DATABASE} > ./dump/data.sql

echo "Data dump completed."

# Create the destination database if it doesn't exist
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  -e "CREATE DATABASE IF NOT EXISTS ${DEST_MYSQL_DATABASE};"

echo "Created destination database if it didn't exist."

# Import the schema (without active triggers and events)
echo "Importing schema to destination..."
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < ./dump/schema.sql

echo "Schema import completed (without active triggers and events)."

# Store the complete schema with triggers and events for future use
echo "Saving complete schema with triggers and events for future activation..."
mkdir -p ./ready_for_promotion
cp ./dump/schema_with_triggers_events.sql ./ready_for_promotion/

echo "Complete schema saved for future activation."

# Import the data with foreign key checks disabled
echo "Importing data to destination with foreign key checks disabled..."
mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} -e "SET FOREIGN_KEY_CHECKS=0;"

mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} < ./dump/data.sql

mysql --host=${DEST_MYSQL_HOST} \
  --port=${DEST_MYSQL_PORT} \
  --user=${DEST_MYSQL_USER} \
  --password=${DEST_MYSQL_PASSWORD} \
  ${DEST_MYSQL_DATABASE} -e "SET FOREIGN_KEY_CHECKS=1;"

echo "Data import completed with foreign key checks restored."

# Import the data
echo "Importing data to destination..."

# Get the current binary log file and position from the source
# This will be used as the starting point for Debezium
BINLOG_INFO=$(mysql --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  -e "SHOW MASTER STATUS\G" | grep -E 'File:|Position:')

BINLOG_FILE=$(echo "$BINLOG_INFO" | grep 'File:' | awk '{print $2}')
BINLOG_POS=$(echo "$BINLOG_INFO" | grep 'Position:' | awk '{print $2}')

echo "Current binary log file: $BINLOG_FILE"
echo "Current binary log position: $BINLOG_POS"

# Save this information to a file for later use in the Debezium connector
cat > ./binlog-position.txt << EOF
BINLOG_FILE=$BINLOG_FILE
BINLOG_POS=$BINLOG_POS
EOF

echo "Initial data sync completed successfully!"
echo "The binary log position has been saved to binlog-position.txt."
echo "You can now start the Debezium replication from this position."