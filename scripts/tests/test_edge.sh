#!/bin/sh
set -e

IMAGE="$1"
if [ -z "$IMAGE" ]; then
  echo "Error: Edge image name required as argument"
  exit 1
fi

echo "[TEST] Edge server with $IMAGE"

# Create a temp docker network
NET="cdn-test-net"
docker network create $NET >/dev/null 2>&1 || true

echo "Starting test origin (name='origin')..."

ORIGIN_IMAGE="origin-img:latest"
# стартуем origin в той же сети
CID_ORIGIN=$(docker run -d \
  --network $NET \
  --network-alias origin_backend \
  --name test-origin \
  -p 0:80 \
  "$ORIGIN_IMAGE")

if [ -z "$CID_ORIGIN" ]; then
  echo "Error: Could not start origin container"
  exit 1
fi

echo "Origin container id: $CID_ORIGIN"

# даём origin подняться
sleep 2

# достаём порт origin
ORIGIN_PORT=$(docker inspect --format '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "$CID_ORIGIN")

if [ -z "$ORIGIN_PORT" ]; then
  echo "Error: Could not get origin port"
  docker logs "$CID_ORIGIN"
  exit 1
fi

echo "Origin is ready."

###############################################################
# START EDGE
###############################################################

CID_EDGE=$(docker run -d \
  --network $NET \
  --name test-edge \
  -p 0:80 \
  "$IMAGE")

if [ -z "$CID_EDGE" ]; then
  echo "Error: Could not start edge container"
  docker rm -f "$CID_ORIGIN" >/dev/null 2>&1 || true
  exit 1
fi

echo "Edge container id: $CID_EDGE"

# получаем порт edge
EDGE_PORT=$(docker inspect --format '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "$CID_EDGE")

if [ -z "$EDGE_PORT" ]; then
  echo "Error: Could not detect mapped port for Edge container"
  docker logs "$CID_EDGE" || true
  exit 1
fi

echo "Edge mapped to host port: $EDGE_PORT"
echo "$EDGE_PORT"

###############################################################
# WAIT FOR EDGE READINESS
###############################################################

EXPECTED="X-Proxy-Cache"

for i in $(seq 1 30); do
  RES=$(curl -s -I "http://localhost:${EDGE_PORT}" || true)

  CODE=$(echo "$RES" | head -n1 | awk '{print $2}')

  if [ "$CODE" = "200" ]; then
    echo "Edge responded with 200 OK at attempt $i"
    echo "$RES"
    docker rm -f "$CID_EDGE" "$CID_ORIGIN" >/dev/null 2>&1 || true
    exit 0
  fi

  echo "Attempt $i/30: Edge returned HTTP ${CODE:-000000}"
  sleep 2
done

###############################################################
# FAILURE
###############################################################

echo "Error: Edge did not respond in time with expected content."
echo "---- edge logs ----"
docker logs "$CID_EDGE" || true

echo "---- origin logs ----"
docker logs "$CID_ORIGIN" || true

docker rm -f "$CID_EDGE" "$CID_ORIGIN" >/dev/null 2>&1 || true
exit 1
