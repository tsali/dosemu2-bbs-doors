#!/bin/bash
# LORD door log rotation
# Runs weekly: compresses logs older than 7 days, deletes logs older than 30 days
# Cron: 0 2 * * 0 (2 AM CST Sunday = midnight Pacific Sunday)

LOGDIR="/tmp"

# Compress logs older than 7 days (skip already compressed)
find "$LOGDIR" -name 'lord-node*-*.log' -mtime +7 -exec gzip -q {} \; 2>/dev/null

# Delete compressed logs older than 30 days
find "$LOGDIR" -name 'lord-node*-*.log.gz' -mtime +30 -delete 2>/dev/null
