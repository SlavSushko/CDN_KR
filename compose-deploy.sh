#!/bin/bash
set -e

echo "=== CDN COMPOSE DEPLOY SCRIPT START ==="

# --- 1. Проверка необходимых инструментов ---
echo "[1/10] Checking required tools..."

if ! command -v git &>/dev/null; then
    echo "Git is not installed!"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "Docker is not installed!"
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo "Docker Compose v2 is not available!"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "curl is not installed!"
    exit 1
fi

echo "All required tools installed"


echo "[2/10] Pulling latest changes..."
git pull origin master || { echo "git pull failed"; exit 1; }
echo "Repository updated"

echo "[3/10] Stopping old containers..."
docker compose down || echo "Some containers were not running"
echo "Containers stopped"

echo "[4/10] Building Docker images..."
docker compose build || { echo "Build failed"; exit 1; }
echo "Images built"

echo "[5/10] Starting Docker Compose environment..."
docker compose up -d || { echo "Failed to start containers"; exit 1; }
echo "Containers started"

echo "[6/10] Validating container states..."
docker compose ps
FAILED=$(docker compose ps --format "{{.State}}" | grep -v "running" || true)
if [[ -n "$FAILED" ]]; then
    echo "Some containers are not running!"
    exit 1
fi
echo "All containers running"

echo "[7/10] Checking HTTP endpoints..."

check_http() {
    local name=$1
    local url=$2

    echo -n "→ Testing $name ($url)... "
    if curl -fs "$url" > /dev/null; then
        echo "OK"
    else
        echo "FAILED"
        exit 1
    fi
}

check_http "Origin"  "http://localhost:8080"
check_http "Edge1"   "http://localhost:8081"
check_http "Edge2"   "http://localhost:8082"
check_http "cAdvisor" "http://localhost:8085"
check_http "Prometheus" "http://localhost:9090"
check_http "Grafana" "http://localhost:3000/login"

echo "All HTTP services available"

echo "[8/10] Checking Redis..."

REDIS_CONTAINER=$(docker compose ps -q redis)

if docker exec "$REDIS_CONTAINER" redis-cli ping | grep -q "PONG"; then
    echo "Redis OK"
else
    echo "Redis FAILED"
    exit 1
fi

echo "[9/10] Checking Prometheus metrics..."

if curl -fs http://localhost:9090/api/v1/targets | grep -q "active"; then
    echo "Prometheus collecting metrics"
else
    echo "Prometheus NOT collecting metrics"
    exit 1
fi

echo "=== CDN COMPOSE DEPLOY SUCCESSFUL ==="
echo "System is running on:"
echo "  • Origin:     http://localhost:8080"
echo "  • Edge1:      http://localhost:8081"
echo "  • Edge2:      http://localhost:8082"
echo "  • Redis:      redis://localhost:6379"
echo "  • cAdvisor:   http://localhost:8085"
echo "  • Prometheus: http://localhost:9090"
echo "  • Grafana:    http://localhost:3000"

exit 0
