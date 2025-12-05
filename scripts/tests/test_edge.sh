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

# Wait until origin responds on its internal port 80
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

# 2) Start edge in same network and publish a random host port
EDGE_CID=$(docker run -d --network "$NETWORK" -p 0:80 "$EDGE_IMAGE")
if [ -z "$EDGE_CID" ]; then
  echo "Error: Unable to start edge container"
  docker rm -f origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi
echo "Edge container id: $EDGE_CID"

# 3) Detect mapped host port for edge (retry)
TRY=0
HOST_PORT=""
while [ $TRY -lt 10 ]; do
  HOST_PORT=$(docker port "$EDGE_CID" 80 | sed -n 's/.*:\([0-9]*\)$/\1/p' || true)
  if [ -n "$HOST_PORT" ]; then
    break
  fi
  TRY=$((TRY+1))
  echo "Waiting for host port mapping... attempt $TRY/10"
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

# 4) Wait for edge to become ready — more tolerant loop with logging
TRIES=0
MAX_TRIES=30
SLEEP_SEC=2
GOOD=0
while [ $TRIES -lt $MAX_TRIES ]; do
  TRIES=$((TRIES+1))
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HOST_PORT}" || echo "000")
  echo "Attempt $TRIES/$MAX_TRIES: Edge returned HTTP $HTTP_CODE"
  if [ "$HTTP_CODE" = "200" ]; then
    # fetch short body and check it's not an nginx error page
    BODY=$(curl -fsS "http://localhost:${HOST_PORT}" 2>/dev/null || echo "")
    echo "Fetched body length: ${#BODY}"
    # simple content check — adjust substring to your origin content (e.g., 'Hairdryer cat' or '<h1>')
    if echo "$BODY" | grep -qEi "Hairdryer|<h1|<!DOCTYPE html>"; then
      GOOD=1
      echo "Edge serving expected content."
      break
    else
      echo "Edge returned 200 but body did not contain expected marker. Body preview:"
      echo "$BODY" | sed -n '1,10p'
    fi
  fi
  sleep $SLEEP_SEC
done

if [ $GOOD -ne 1 ]; then
  echo "Error: Edge did not respond in time with expected content."
  echo "---- edge logs ----"
  docker logs "$EDGE_CID" || true
  echo "---- origin logs ----"
  docker logs origin || true
  docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  exit 1
fi

# success — print headers for confirmation
echo "Edge ready — printing response headers:"
curl -fsS -I "http://localhost:${HOST_PORT}" | sed -n '1,20p' || true

# Cleanup
docker rm -f "$EDGE_CID" origin >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true

exit 0
