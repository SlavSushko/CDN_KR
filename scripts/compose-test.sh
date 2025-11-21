set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Compose test ==="

declare -A urls=(
  ["Origin"]="http://localhost:8080"
  ["Edge1"]="http://localhost:8081"
  ["Edge2"]="http://localhost:8082"
  ["cAdvisor"]="http://localhost:8085/containers/"
  ["Prometheus"]="http://localhost:9090/api/v1/targets"
  ["Grafana"]="http://localhost:3000/login"
)

for name in "${!urls[@]}"; do
  url="${urls[$name]}"
  printf "Testing %s (%s)... " "$name" "$url"
  if curl -fsS "$url" -o /dev/null; then
    echo "OK"
  else
    echo "FAILED"
    exit 1
  fi
done

REDIS_CID=$(docker compose ps -q redis)
if [ -n "$REDIS_CID" ]; then
  if docker exec "$REDIS_CID" redis-cli -a admin ping | grep -q PONG; then
    echo "Redis OK"
  else
    echo "Redis FAILED"
    exit 1
  fi
else
  echo "Redis container not found"
  exit 1
fi

echo "All compose tests passed."
exit 0