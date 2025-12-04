#!/bin/sh
set -eu

EDGE_IMAGE="$1"
if [ -z "$EDGE_IMAGE" ]; then
  echo "Error: Edge image required as argument"
  exit 1
fi

echo "[TEST] Edge server with $EDGE_IMAGE"

NETWORK="cdn-test-net"

# create network if missing
docker network create "$NETWORK" >/dev/null 2>&1 || true

# ensure no leftover container named 'origin'
docker rm -f origin >/dev/null 2>&1 || true

# 1) Start origin with name 'origin' in the test network
echo "Starting test origin (name='origin')..."
ORIGIN_CID=$(docker run -d --network "$NETWORK" --name origin origin-img:latest)
if [ -z "$ORIGIN_CID" ]; then
  echo "Error: Unable to start origin container"
  exit 1
fi
echo "Origin container id: $ORIGIN_CID"

# 2) Wait until origin responds on its internal port 80
TRIES=0
MAX_TRIES=15
until docker exec origin sh -c "curl -sS --fail http://localhost:80 >/dev/null 2>&1" || [ $TRIES -ge $MAX_TRIES ]; do
  TRIES=$((TRIES+1))
  echo "Waiting for origin to be ready... attempt $TRIES/$MAX_TRIES"
  sleep 1
done

if [ $TRIES -ge $MAX_TRIES ]; then
  echo "Error: origin did not become ready in time"
  echo "---- origin logs ----"
  docker logs origin || true
  docker rm -f origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi
echo "Origin is ready."

# 3) Start edge in same network and publish a random host port
EDGE_CID=$(docker run -d --network "$NETWORK" -p 0:80 "$EDGE_IMAGE")
if [ -z "$EDGE_CID" ]; then
  echo "Error: Unable to start edge container"
  docker rm -f origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi
echo "Edge container id: $EDGE_CID"

# 4) Detect mapped host port for edge (retry)
TRY=0
HOST_PORT=""
while [ $TRY -lt 10 ]; do
  HOST_PORT=$(docker port "$EDGE_CID" 80 | sed -n 's/.*:\([0-9]*\)$/\1/p' || true)
  if [ -n "$HOST_PORT" ]; then
    break
  fi
  TRY=$((TRY+1))
  sleep 1
done

if [ -z "$HOST_PORT" ]; then
  echo "Error: Could not detect mapped port for Edge container."
  echo "---- edge logs ----"
  docker logs "$EDGE_CID" || true
  echo "---- origin logs ----"
  docker logs origin || true
  docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge mapped to host port: $HOST_PORT"

# 5) Wait for edge to become ready (try curl)
TRIES=0
MAX_TRIES=15
until curl -sS --fail "http://localhost:${HOST_PORT}" >/dev/null 2>&1 || [ $TRIES -ge $MAX_TRIES ]; do
  TRIES=$((TRIES+1))
  echo "Waiting for edge to be ready... attempt $TRIES/$MAX_TRIES"
  sleep 1
done

if [ $TRIES -ge $MAX_TRIES ]; then
  echo "Error: Edge did not respond in time."
  echo "---- edge logs ----"
  docker logs "$EDGE_CID" || true
  echo "---- origin logs ----"
  docker logs origin || true
  docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi

# 6) Fetch and print response headers (sanity)
RESPONSE_HEADERS=$(curl -fsS -I "http://localhost:${HOST_PORT}" | head -n 10 || true)
if [ -z "$RESPONSE_HEADERS" ]; then
  echo "Error: Edge server returned empty response"
  echo "---- edge logs ----"
  docker logs "$EDGE_CID" || true
  echo "---- origin logs ----"
  docker logs origin || true
  docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge response OK"
echo "$RESPONSE_HEADERS"

# Cleanup
docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true

exit 0
