set -euo pipefail

PROM_URL="${PROM_URL:-http://localhost:9090}"
REQUIRED_TARGETS=( "cadvisor:8080" "origin:80" "edge1:80" "edge2:80" )
MIN_UP=4

echo "== Prometheus smoke test =="
echo "Prometheus URL: $PROM_URL"

if ! curl -fsS "${PROM_URL}/-/ready" > /dev/null 2>&1; then
  echo "Prometheus not ready at ${PROM_URL}"
  exit 1
fi
echo "Prometheus ready"

targets_json=$(curl -fsS "${PROM_URL}/api/v1/targets")

count_up=$(echo "$targets_json" | jq -r '.data.activeTargets[] | select(.health=="up") | .labels.__address__' 2>/dev/null | wc -l)
echo "Active targets with health=up: $count_up"

missing=0
for t in "${REQUIRED_TARGETS[@]}"; do
  found=$(echo "$targets_json" | jq -r --arg T "$t" '.data.activeTargets[] | select(.labels.__address__==$T) | .health' 2>/dev/null || true)
  if [[ "$found" != "up" ]]; then
    echo "Target $t missing or not up (health=$found)"
    missing=$((missing+1))
  else
    echo "Target $t is up"
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "One or more required targets are not up"
  exit 2
fi

cpu_count=$(curl -fsS "${PROM_URL}/api/v1/query?query=container_cpu_usage_seconds_total" | jq -r '.data.result | length' 2>/dev/null || echo 0)
if [[ "$cpu_count" -gt 0 ]]; then
  echo "container_cpu_usage_seconds_total present (samples: $cpu_count)"
else
  echo "container_cpu_usage_seconds_total not found (Prometheus may not be scraping cAdvisor)."
fi

echo "== Prometheus tests passed =="
exit 0