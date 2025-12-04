#!/bin/sh
set -e
IMAGE="$1"
if [ -z "$IMAGE" ]; then
  echo "Error: Image name required as argument"
  exit 1
fi
echo "[TEST] Origin server with $IMAGE"
CID=$(docker run -d -p 0:80 "$IMAGE")
if [ -z "$CID" ]; then
  echo "Error: Unable to start origin container"
  exit 1
fi
# Use docker inspect for reliable port extraction
HOST_PORT=$(docker inspect --format '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "$CID")
if [ -z "$HOST_PORT" ] || ! echo "$HOST_PORT" | grep -qE '^[0-9]+$'; then
  echo "Error: Could not detect valid mapped port for Origin container."
  docker logs "$CID" || true
  docker rm -f "$CID" >/dev/null 2>&1 || true
  exit 1
fi
echo "Origin mapped to port: $HOST_PORT"
sleep 2  # Increased sleep for container readiness
URL="http://localhost:${HOST_PORT}/"
RESPONSE=$(curl -fsS -v "$URL" 2>&1 | head -n 5)  # Added -v for verbose debug
if [ -z "$RESPONSE" ]; then
  echo "Error: Origin server returned empty response"
  docker logs "$CID" || true
  docker rm -f "$CID" >/dev/null 2>&1 || true
  exit 1
fi
echo "Origin response OK"
echo "$RESPONSE"
docker rm -f "$CID" >/dev/null 2>&1 || true
exit 0