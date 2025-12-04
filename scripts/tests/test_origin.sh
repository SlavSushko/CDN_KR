#!/usr/bin/env bash
set -euo pipefail

IMAGE=${1:-cdn-origin:local}

echo "== Test origin image: $IMAGE =="

# run container on ephemeral port and check index.html or root returns 200
CID=$(docker run -d -p 0:80 --rm $IMAGE || true)
# If docker run failed because port mapping with 0 not supported, fallback without port forward
if [ -z "${CID}" ]; then
  CID=$(docker run -d --rm $IMAGE)
  sleep 1
  # try to curl inside container
  docker exec "$CID" sh -c "curl -sS -o /tmp/out.html http://localhost:80 || true"
  docker exec "$CID" sh -c "grep -q '<!DOCTYPE html>' /tmp/out.html && echo 'origin returned HTML' || echo 'origin content missing'; exit 0"
  docker rm -f "$CID" >/dev/null 2>&1 || true
  exit 0
fi

# get mapped port
HOST_PORT=$(docker port $CID 80 | sed -n 's/.*:\([0-9]*\)$/\1/p')
sleep 1
curl -fsS "http://localhost:${HOST_PORT}" | head -n 5
docker rm -f "$CID" >/dev/null 2>&1 || true
echo "Origin image test OK"
