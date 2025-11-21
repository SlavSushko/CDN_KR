set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Compose deploy (dev + monitoring) ==="

if docker info 2>/dev/null | grep -q "Swarm: active"; then
  echo "Swarm is active — leaving swarm to run compose (will not affect cluster nodes)."
  docker swarm leave --force || true
fi

echo "[1] Pull latest from git..."
git pull origin master || true

echo "[2] Build images (local tags)..."
docker compose build

echo "[3] Bring down old compose if any..."
docker compose down || true

echo "[4] Start compose..."
docker compose up -d

echo "[5] Wait a few seconds for services to start..."
sleep 6

echo "[6] Show status..."
docker compose ps

echo "Compose deploy finished. Access:"
echo "  Origin:     http://localhost:8080"
echo "  Edge1:      http://localhost:8081"
echo "  Edge2:      http://localhost:8082"
echo "  cAdvisor:   http://localhost:8085"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000 (admin/admin)"

exit 0