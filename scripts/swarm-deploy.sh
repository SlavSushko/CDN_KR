set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

STACK_FILE="docker-stack.yaml"
STACK_NAME="cdn_stack"
NET_NAME="cdn-net"

echo "=== Swarm deploy ==="

if ! command -v docker &>/dev/null; then
  echo "Docker not found"; exit 1
fi

if ! docker info | grep -q "Swarm: active"; then
  echo "[1] Initializing Docker Swarm..."
  docker swarm init || { echo "Failed to init swarm"; exit 1; }
else
  echo "Swarm already active"
fi

if ! docker network ls --format '{{.Name}}' | grep -q "^${NET_NAME}$"; then
  echo "[2] Creating overlay network ${NET_NAME}..."
  docker network create -d overlay --attachable "${NET_NAME}" || { echo "Failed to create network"; exit 1; }
else
  echo "Overlay network ${NET_NAME} exists"
fi

echo "[3] Building images for swarm (local tags)..."
docker build -t origin-img:latest ./origin
docker build -t edge-img:latest ./edge


echo "[4] Removing existing stack (if any)..."
docker stack rm "${STACK_NAME}" || true
sleep 3

echo "[5] Deploying stack from ${STACK_FILE}..."
docker stack deploy -c "${STACK_FILE}" "${STACK_NAME}"

echo "Swarm deploy initiated. Use 'docker stack services ${STACK_NAME}' to inspect."
exit 0