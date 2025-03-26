### 7. Set Up Schema Synchronization

To periodically capture schema objects (triggers, procedures, and events) from the source database:

1. Make the schema sync scripts executable:

   ```bash
   chmod +x schema-sync.sh
   chmod +x schema-sync-cron.sh
   ```

2. Run the initial schema sync:

   ```bash
   ./schema-sync.sh
   ```

3. Set up a scheduled job to run the sync periodically:

   ```bash
   crontab -e
   ```

   Add a line like:

   ```
   0 0 * * * /path/to/schema-sync-cron.sh >> /path/to/schema-sync-cron.log 2>&1
   ```

   This will sync the schema daily at midnight.

   Note: The script retains the 5 most recent schema syncs and automatically updates the "latest" pointer.# MySQL Replication with Debezium and Kafka (Using Environment Variables)

This guide explains how to set up MySQL replication from Server A to Server B using Debezium and Kafka with Docker Compose, using environment variables for sensitive information.

## Prerequisites

- Docker and Docker Compose installed on a server or machine that can access both MySQL instances
- Network connectivity between:
  - Your Docker environment and both MySQL servers
  - Between the two MySQL servers

## Setup Steps

### 1. Configure Source MySQL (Server A)

1. Apply the MySQL configuration to enable binary logging (if not already enabled):

   Edit the MySQL configuration file (usually `/etc/mysql/my.cnf` or `/etc/mysql/mysql.conf.d/mysqld.cnf`):

   ```ini
   [mysqld]
   server-id=1
   log_bin=mysql-bin
   binlog_format=ROW
   binlog_row_image=FULL
   expire_logs_days=10
   gtid_mode=ON                # Enable GTID (optional but recommended)
   enforce_gtid_consistency=ON # Required when gtid_mode is ON
   ```

2. Restart MySQL to apply the configuration:

   ```bash
   sudo systemctl restart mysql
   ```

3. Create the Debezium user by running the SQL commands in `mysql-source-setup.sql`

### 2. Prepare Docker Environment

1. Create a directory for the project:

   ```bash
   mkdir mysql-replication
   cd mysql-replication
   ```

2. Create the following files using the provided artifacts:
   - `docker-compose.yml`
   - `.env`
   - `create-source-connector.sh`
   - `create-sink-connector.sh`

3. Configure your environment variables:

   Edit the `.env` file to set:
   - Source MySQL connection details
   - Destination MySQL connection details
   - Kafka and Connect port configurations

4. Make the connector scripts executable:

   ```bash
   chmod +x create-source-connector.sh
   chmod +x create-sink-connector.sh
   ```

### 3. Start the Services

1. Start all services:

   ```bash
   docker-compose up -d
   ```

2. Verify that all services are running:

   ```bash
   docker-compose ps
   ```

3. Check Kafka Connect logs for any issues:

   ```bash
   docker-compose logs -f connect
   ```

### 4. Synchronize Initial Data

1. Make the initial data sync script executable:

   ```bash
   chmod +x initial-data-sync.sh
   ```

2. Run the initial data synchronization:

   ```bash
   ./initial-data-sync.sh
   ```

   This will:
   - Dump the schema and data from the source database
   - Create the destination database if it doesn't exist
   - Import the schema and data to the destination
   - Record the current binary log position for Debezium to start from

3. Verify that data was synchronized properly by checking both databases

   Note: This process imports the database schema without active triggers and events on the destination database. The complete schema with triggers and events is saved for future activation if needed. Foreign key checks are disabled during data import to avoid constraint errors.

### 5. Deploy the Connectors

1. Deploy the source connector using the script:

   ```bash
   ./create-source-connector.sh
   ```

2. Deploy the sink connector using the script:

   ```bash
   ./create-sink-connector.sh
   ```

3. Verify the connectors are running:

   ```bash
   source .env
   curl -X GET http://localhost:${KAFKA_CONNECT_PORT}/connectors
   curl -X GET http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-source-connector/status
   curl -X GET http://localhost:${KAFKA_CONNECT_PORT}/connectors/mysql-sink-connector/status
   ```

### 6. Monitoring

1. Access the Kafka UI at `http://localhost:${KAFKA_UI_PORT}` to monitor:
   - Topics and messages
   - Connector status
   - Consumer groups

2. Check for data replication by comparing data on both servers

### 8. Promoting Destination to Primary (When Needed)

If you need to promote the destination database to become the primary database:

1. Make the promotion script executable:

   ```bash
   chmod +x promote-to-primary.sh
   ```

2. Run the promotion script:

   ```bash
   ./promote-to-primary.sh
   ```

   This script will:
   - Stop the replication connectors
   - Import the most recent complete schema with triggers and events (using the latest schema sync)
   - Enable the event scheduler
   - Make the destination database ready to be used as the primary database

## Troubleshooting

1. **Connector Failures**:
   - Check connector logs: `curl -X GET http://localhost:8083/connectors/mysql-source-connector/status`
   - Verify MySQL user permissions
   - Ensure binary logging is enabled

2. **Network Issues**:
   - Verify connectivity between Docker and both MySQL servers
   - Check if MySQL ports are accessible (default 3306)

3. **Schema Compatibility**:
   - Ensure destination tables have the same schema as source tables
   - Primary keys must be defined consistently

4. **Restart Failed Connectors**:
   - Delete and recreate the connector if needed:
     ```bash
     curl -X DELETE http://localhost:8083/connectors/mysql-source-connector
     curl -X POST -H "Content-Type: application/json" --data @mysql-source-connector.json http://localhost:8083/connectors
     ```