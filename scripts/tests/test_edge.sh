#!/bin/sh
set -e

EDGE_IMAGE="$1"
if [ -z "$EDGE_IMAGE" ]; then
  echo "Error: Edge image required as argument"
  exit 1
fi

echo "[TEST] Edge server with $EDGE_IMAGE"

NETWORK="cdn-test-net"
docker network create $NETWORK >/dev/null 2>&1 || true

ORIGIN_CID=$(docker run -d --network $NETWORK --name origin-test origin-img:latest)
sleep 2

CID=$(docker run -d -p 0:80 --network $NETWORK "$EDGE_IMAGE")
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
  docker logs "$CID"
  docker rm -f "$CID"
  docker rm -f "$ORIGIN_CID"
  exit 1
fi

echo "Edge mapped to port: $HOST_PORT"
sleep 2

RESPONSE=$(curl -fsS "http://localhost:${HOST_PORT}" -I | head -n 5)

if [ -z "$RESPONSE" ]; then
  echo "Error: Edge server returned empty response"
  docker logs "$CID"
  docker rm -f "$CID"
  docker rm -f "$ORIGIN_CID"
  exit 1
fi

echo "Edge response OK"
echo "$RESPONSE"

docker rm -f "$CID" >/dev/null 2>&1 || true
docker rm -f "$ORIGIN_CID" >/dev/null 2>&1 || true
docker network rm $NETWORK >/dev/null 2>&1 || true
exit 0
