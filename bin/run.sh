#!/usr/bin/env bash
set -e

echo "## Checking & stopping previous officer process..."
if [ -f /tmp/officer.pid ]; then
  kill -9 `cat /tmp/officer.pid` || true
  rm /tmp/officer.pid
fi

echo "## Starting officer application..."
bundle exec bin/officer start -- -d /tmp

echo "## Keep container running"
tail -f /dev/null
