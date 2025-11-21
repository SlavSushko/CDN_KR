echo "Проверка бинарников..."
command -v docker >/dev/null || { echo "Docker не установлен"; exit 1; }
command -v git >/dev/null || { echo "Git не установлен"; exit 1; }

echo "Получение обновлений..."
git pull origin master || continue

echo "Сборка Docker-образов..."
docker build -t origin-img ./origin || exit 1
docker build -t edge-img ./edge || exit 1

echo "Остановка compose окружения..."
docker compose down || true

echo "Проверка режима Swarm..."
if ! docker info | grep -q "Swarm: active"; then
    echo "Swarm не активен — активирую"
    docker swarm init || exit 1
fi

echo "Удаление старого стека..."
docker stack rm cdn_stack || true
sleep 5

echo "Подготовка overlay-сети cdn-net..."
docker network rm cdn-net >/dev/null 2>&1 || true
docker network create --driver=overlay --attachable cdn-net || true
sleep 2

echo "Деплой нового стека..."
docker stack deploy -c stack.yaml cdn_stack || exit 1

echo "Ожидание запуска сервисов..."
sleep 10

echo "Проверка edge1..."
curl -f http://localhost:8081 || { echo "Edge1 недоступен"; exit 1; }

echo "Готово! Swarm запущен."