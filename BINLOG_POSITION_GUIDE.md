# Binlog Position Management Guide

This guide explains how to manage the `binlog-position.txt` file for recovery purposes in your Debezium MySQL replication setup.

## Overview

The `binlog-position.txt` file contains the current binary log position from your source MySQL server. This position is crucial for:
- Starting Debezium replication from a specific point
- Recovering from failures without losing data
- Ensuring data consistency during replication restarts

## File Format

The `binlog-position.txt` file contains:
```
BINLOG_FILE=mysql-bin.000123
BINLOG_POS=456789
```

## How to Update Binlog Position

### Option 1: Manual Updates

Use the manual update script when you want to capture the current position:

```bash
./update-binlog-position.sh
```

This script:
- Connects to the source MySQL server
- Gets the current `SHOW MASTER STATUS`
- Updates `binlog-position.txt` with the latest position
- Displays the new position

### Option 2: Automated Updates with Cron

For continuous monitoring, set up a cron job to update the position periodically:

1. **Set up the cron job:**
   ```bash
   crontab -e
   ```

2. **Add a line to update every 5 minutes:**
   ```
   */5 * * * * /path/to/your/debezium-mysql-replication/update-binlog-position-cron.sh
   ```

3. **Or update every hour:**
   ```
   0 * * * * /path/to/your/debezium-mysql-replication/update-binlog-position-cron.sh
   ```

The automated script includes:
- Error handling and logging
- Log rotation (keeps last 1000 lines)
- Timestamped entries

### Option 3: Integration with Existing Scripts

You can also integrate binlog position updates into your existing workflow:

```bash
# After schema sync
./schema-sync.sh && ./update-binlog-position.sh

# Before important operations
./update-binlog-position.sh && ./some-important-operation.sh
```

## Recovery Process

### Using the Recovery Script

When you need to restart replication from the last known position:

```bash
./recover-from-position.sh
```

This script:
1. Loads the saved binlog position
2. Verifies the position is still valid on the source
3. Stops existing connectors
4. Restarts connectors using the saved position
5. Provides monitoring commands

### Manual Recovery Steps

If you prefer manual recovery:

1. **Check the saved position:**
   ```bash
   cat binlog-position.txt
   ```

2. **Verify it's still valid:**
   ```bash
   mysql --host=${SOURCE_MYSQL_HOST} --port=${SOURCE_MYSQL_PORT} \
     --user=${SOURCE_MYSQL_USER} --password=${SOURCE_MYSQL_PASSWORD} \
     -e "SHOW MASTER STATUS\G"
   ```

3. **Restart connectors:**
   ```bash
   ./create-source-connector.sh
   ./create-sink-connector.sh
   ```

## Best Practices

### 1. Update Frequency

- **High-traffic databases:** Update every 5-15 minutes
- **Low-traffic databases:** Update every hour
- **Before maintenance:** Always update before planned downtime

### 2. Monitoring

Monitor the update process:
```bash
# Check the log file
tail -f binlog-position-update.log

# Check the current position
cat binlog-position.txt

# Verify against source
mysql --host=${SOURCE_MYSQL_HOST} --port=${SOURCE_MYSQL_PORT} \
  --user=${SOURCE_MYSQL_USER} --password=${SOURCE_MYSQL_PASSWORD} \
  -e "SHOW MASTER STATUS\G"
```

### 3. Backup Strategy

Consider backing up the position file:
```bash
# Create a backup before important operations
cp binlog-position.txt binlog-position.txt.backup.$(date +%Y%m%d_%H%M%S)
```

### 4. Error Handling

The automated script includes error handling, but you should also:
- Monitor the log file for errors
- Set up alerts for failed updates
- Have a fallback strategy if the position becomes stale

## Troubleshooting

### Position Too Old

If the saved position is too old (binlog file has rotated):

1. **Check if the file still exists:**
   ```bash
   mysql --host=${SOURCE_MYSQL_HOST} --port=${SOURCE_MYSQL_PORT} \
     --user=${SOURCE_MYSQL_USER} --password=${SOURCE_MYSQL_PASSWORD} \
     -e "SHOW BINARY LOGS;"
   ```

2. **If the file is gone, you may need to:**
   - Perform a fresh initial data sync
   - Or use a more recent position if available

### Connection Issues

If the update script fails to connect:
- Check network connectivity
- Verify MySQL credentials
- Ensure the MySQL user has `REPLICATION SLAVE` privileges

### Permission Issues

Ensure the scripts are executable:
```bash
chmod +x update-binlog-position.sh
chmod +x update-binlog-position-cron.sh
chmod +x recover-from-position.sh
```

## Integration with Your Workflow

### Before Maintenance

```bash
# Update position before maintenance
./update-binlog-position.sh

# Perform maintenance...

# Recover after maintenance
./recover-from-position.sh
```

### Regular Monitoring

Add to your monitoring dashboard:
- Last update timestamp
- Current binlog position
- Age of the position file
- Update script success/failure rate

### Disaster Recovery

Include in your disaster recovery plan:
1. Backup the `binlog-position.txt` file
2. Document the recovery process
3. Test recovery procedures regularly
4. Have fallback positions if needed

## Security Considerations

- The `binlog-position.txt` file contains sensitive connection information
- Ensure proper file permissions: `chmod 600 binlog-position.txt`
- Consider encrypting the file for additional security
- Rotate MySQL passwords regularly and update the position file accordingly 