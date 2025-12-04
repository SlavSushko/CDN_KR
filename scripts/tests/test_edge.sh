#!/bin/sh
set -e

IMAGE="$1"
if [ -z "$IMAGE" ]; then
  echo "Error: Image name required as argument"
  exit 1
fi

echo "[TEST] Edge server with $IMAGE"

# ------------------------------------------------------
# 1. Start temporary ORIGIN for the test
# ------------------------------------------------------
ORIGIN_CID=$(docker run -d -p 0:80 origin-img:latest)
if [ -z "$ORIGIN_CID" ]; then
  echo "Error: Unable to start test-origin container"
  exit 1
fi

ORIGIN_PORT=$(docker inspect --format '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "$ORIGIN_CID")
echo "Test-origin started on port: $ORIGIN_PORT"

export ORIGIN_URL="http://localhost:${ORIGIN_PORT}"

# ------------------------------------------------------
# 2. Start edge with environment variable ORIGIN_URL
# ------------------------------------------------------
CID=$(docker run -d -p 0:80 -e ORIGIN_URL="$ORIGIN_URL" "$IMAGE")
if [ -z "$CID" ]; then
  echo "Error: Unable to start edge container"
  docker rm -f "$ORIGIN_CID" >/dev/null 2>&1
  exit 1
fi

# Read mapped port
TRY=0
HOST_PORT=""
while [ $TRY -lt 5 ]; do
  HOST_PORT=$(docker port "$CID" 80 | sed -n 's/.*:\([0-9]*\)$/\1/p')
  if [ -n "$HOST_PORT" ]; then break; fi
  TRY=$((TRY+1))
  sleep 1
done

if [ -z "$HOST_PORT" ]; then
  echo "Error: Could not detect mapped port for Edge container"
  docker logs "$CID" || true
  docker rm -f "$CID" "$ORIGIN_CID" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge mapped to port: $HOST_PORT"

# ------------------------------------------------------
# 3. Test edge response
# ------------------------------------------------------
sleep 1

RESPONSE=$(curl -fsS "http://localhost:${HOST_PORT}" -I | head -n 5)

if [ -z "$RESPONSE" ]; then
  echo "Error: Edge server returned empty response"
  docker logs "$CID" || true
  docker rm -f "$CID" "$ORIGIN_CID" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge response OK"
echo "$RESPONSE"

docker rm -f "$CID" "$ORIGIN_CID" >/dev/null 2>&1 || true
exit 0
