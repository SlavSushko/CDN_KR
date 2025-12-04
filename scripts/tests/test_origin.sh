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

HOST_PORT=$(docker inspect --format '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "$CID")

if [ -z "$HOST_PORT" ]; then
  echo "Error: Failed to get mapped port."
  docker logs "$CID"
  docker rm -f "$CID"
  exit 1
fi

echo "Origin mapped to port: $HOST_PORT"
sleep 2

RESPONSE=$(curl -fsS "http://localhost:${HOST_PORT}" -I | head -n 5)

if [ -z "$RESPONSE" ]; then
  echo "Error: Origin server returned empty response."
  docker logs "$CID"
  docker rm -f "$CID"
  exit 1
fi

echo "Origin response OK"
echo "$RESPONSE"

docker rm -f "$CID" >/dev/null 2>&1 || true
exit 0
