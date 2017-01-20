#!/usr/bin/env bash
set -e

echo "## Start application"
officer start -- -d /tmp

echo "## Keep container running"
tail -f /dev/null
