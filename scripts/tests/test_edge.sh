#!/bin/sh
set -e
IMAGE="$1"
if [ -z "$IMAGE" ]; then
  echo "Error: Image name required as argument"
  exit 1
fi
echo "[TEST] Edge server with $IMAGE"
CID=$(docker run -d -p 0:80 "$IMAGE")
# ... остальной код ...
if [ -z "$CID" ]; then
  echo "Error: Unable to start edge container"
  exit 1
fi

TRY=0
HOST_PORT=""
while [ $TRY -lt 5 ]; do
  HOST_PORT=$(docker port $CID 80 | sed -n 's/.*:\([0-9]*\)$/\1/p')
  if [ -n "$HOST_PORT" ]; then break; fi
  TRY=$((TRY+1))
  sleep 1
done

if [ -z "$HOST_PORT" ]; then
  echo "Error: Could not detect mapped port for Edge container."
  docker port "$CID" || true
  docker logs "$CID" || true
  docker rm -f "$CID" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge mapped to port: $HOST_PORT"

sleep 1

RESPONSE=$(curl -fsS "http://localhost:${HOST_PORT}" -I | head -n 5)

if [ -z "$RESPONSE" ]; then
  echo "Error: Edge server returned empty response"
  docker logs "$CID" || true
  docker rm -f "$CID" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge response OK"
echo "$RESPONSE"

docker rm -f "$CID" >/dev/null 2>&1 || true
exit 0
