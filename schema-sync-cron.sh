#!/bin/bash

# Define the path to your script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCHEMA_SYNC_SCRIPT="${SCRIPT_DIR}/schema-sync.sh"

# Check if the script exists
if [ ! -f "${SCHEMA_SYNC_SCRIPT}" ]; then
    echo "Error: Schema sync script not found at: ${SCHEMA_SYNC_SCRIPT}"
    exit 1
fi

# Make sure the script is executable
chmod +x "${SCHEMA_SYNC_SCRIPT}"

# Run the schema sync
${SCHEMA_SYNC_SCRIPT}

# Retain only the last 5 schema syncs to save disk space
cd "${SCRIPT_DIR}/ready_for_promotion"
# Skip 'latest' symlink and sort by timestamp
SYNC_DIRS=$(ls -1d schema_sync_* | sort -r)
COUNT=0
for DIR in ${SYNC_DIRS}; do
    COUNT=$((COUNT+1))
    if [ ${COUNT} -gt 5 ]; then
        echo "Removing old schema sync: ${DIR}"
        rm -rf "${DIR}"
    fi
done

echo "Schema sync cron job completed successfully"

# To set up the cron job, run:
# crontab -e
# And add a line like:
# 0 0 * * * /path/to/schema-sync-cron.sh >> /path/to/schema-sync-cron.log 2>&1
# This will run the script daily at midnight