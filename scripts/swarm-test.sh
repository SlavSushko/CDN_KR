set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

STACK_NAME="cdn_stack"
echo "=== Swarm test ==="

docker stack services "${STACK_NAME}" --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"

sleep 5

services=(origin edge1 edge2 redis prometheus grafana node-exporter swarm-exporter)
for s in "${services[@]}"; do
  echo "Checking $s..."
  if ! docker service ls --format '{{.Name}} {{.Replicas}}' | grep -q "${STACK_NAME}_${s}"; then
    echo "Service ${s} missing (or not created)"
  else
    # check replicas
    replicas=$(docker service ls --format '{{.Name}} {{.Replicas}}' | grep "${STACK_NAME}_${s}" | awk '{print $2}')
    echo "Replicas: $replicas"
  fi
done

urls=(
  "http://localhost:8080"
  "http://localhost:8081"
  "http://localhost:8082"
  "http://localhost:9090"
  "http://localhost:3000"
)
for u in "${urls[@]}"; do
  printf "Testing %s ... " "$u"
  if curl -fsS "$u" -o /dev/null; then
    echo "OK"
  else
    echo "FAILED"
  fi
done
echo "Running Prometheus metric tests on manager..."
if ping -c 1 localhost >/dev/null 2>&1; then
  echo "Local Prometheus check (manager) via script..."
  ./scripts/prometheus-test.sh || { echo "Prometheus tests failed"; exit 1; }
else
  echo "Skipping local prometheus test"
fi

echo "Swarm test completed."
exit 0