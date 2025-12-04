#!/usr/bin/env bash
set -euo pipefail

IMAGE=${1:-redis:latest}

echo "== Test Redis image: $IMAGE =="

# quick check: start redis, run redis-cli ping, then stop
CID=$(docker run -d --rm $IMAGE)
sleep 1
docker exec "$CID" redis-cli ping | grep -q PONG
docker rm -f "$CID" >/dev/null 2>&1 || true
echo "Redis ping OK"
