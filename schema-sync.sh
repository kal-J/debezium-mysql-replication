#!/bin/bash

# Load environment variables
source .env

# Set timestamp for this sync
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SYNC_DIR="./ready_for_promotion/schema_sync_${TIMESTAMP}"

echo "Starting schema synchronization at ${TIMESTAMP}..."
mkdir -p "${SYNC_DIR}"

# Create a log file
LOG_FILE="${SYNC_DIR}/sync.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "Syncing triggers, stored procedures, and events from source database..."

# Dump triggers
echo "Extracting triggers..."
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --no-create-info \
  --no-create-db \
  --skip-routines \
  --skip-opt \
  --triggers \
  --skip-comments \
  ${SOURCE_MYSQL_DATABASE} > "${SYNC_DIR}/triggers.sql"

# Dump stored procedures and functions
echo "Extracting stored procedures and functions..."
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --no-create-info \
  --no-create-db \
  --skip-triggers \
  --routines \
  --skip-comments \
  ${SOURCE_MYSQL_DATABASE} > "${SYNC_DIR}/routines.sql"

# Dump events
echo "Extracting events..."
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --no-create-info \
  --no-create-db \
  --skip-triggers \
  --skip-routines \
  --events \
  --skip-comments \
  ${SOURCE_MYSQL_DATABASE} > "${SYNC_DIR}/events.sql"

# Dump table structures (to capture the latest table definitions)
echo "Extracting table structures..."
mysqldump --host=${SOURCE_MYSQL_HOST} \
  --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} \
  --password=${SOURCE_MYSQL_PASSWORD} \
  --no-data \
  --skip-triggers \
  --skip-routines \
  --skip-events \
  ${SOURCE_MYSQL_DATABASE} > "${SYNC_DIR}/table_structures.sql"

# Create a consolidated SQL file that includes all objects
echo "Creating consolidated schema file..."
cat "${SYNC_DIR}/table_structures.sql" > "${SYNC_DIR}/complete_schema.sql"
cat "${SYNC_DIR}/routines.sql" >> "${SYNC_DIR}/complete_schema.sql"
cat "${SYNC_DIR}/triggers.sql" >> "${SYNC_DIR}/complete_schema.sql"
cat "${SYNC_DIR}/events.sql" >> "${SYNC_DIR}/complete_schema.sql"

# Update the latest symlink to point to the most recent schema sync
echo "Updating latest schema symlink..."
ln -sf "schema_sync_${TIMESTAMP}" "./ready_for_promotion/latest"

# Create a metadata file with information about this sync
cat > "${SYNC_DIR}/metadata.txt" << EOF
Schema Synchronization
=====================
Timestamp: $(date)
Source Database: ${SOURCE_MYSQL_DATABASE}
Source Host: ${SOURCE_MYSQL_HOST}

This directory contains the following SQL dump files:
- table_structures.sql: Database table definitions
- routines.sql: Stored procedures and functions
- triggers.sql: Database triggers
- events.sql: MySQL events
- complete_schema.sql: Consolidated schema with all objects

These files are for reference and can be used during database promotion.
EOF

echo "Schema synchronization completed successfully."
echo "Schema files saved to: ${SYNC_DIR}"
echo "To use during promotion, update the promote-to-primary.sh script to use:"
echo "  ./ready_for_promotion/latest/complete_schema.sql"