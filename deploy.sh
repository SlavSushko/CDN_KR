
if ! command -v git &> /dev/null; then
    echo "Ошибка: Git не установлен. Установите Git и попробуйте снова."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Ошибка: Docker не установлен. Установите Docker и попробуйте снова."
    exit 1
fi

echo "Pull обновлений из Git..."
git pull origin main || { echo "Ошибка git pull. Проверьте repo."; exit 1; }

echo "Остановка существующих контейнеров..."
docker compose down || { echo "Ошибка docker compose down. Продолжаем..."; }

echo "Сборка и запуск системы..."
docker compose up -d --build || { echo "Ошибка docker compose up. Проверьте yaml."; exit 1; }

echo "Деплой в Swarm..."
docker stack deploy -c docker-compose.yaml cdn_stack || { echo "Ошибка stack deploy."; exit 1; }

echo "Тестирование деплоя..."
curl -f http://localhost:8081 || { echo "Тест failed: Edge не доступен."; exit 1; }
echo "Деплой успешен! Система запущена на localhost:8081."

exit 0