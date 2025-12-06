FROM nginx:latest

# Значение по умолчанию — используется в Docker Swarm
ENV ORIGIN_HOST=origin:80

# Копируем шаблон в директорию, которую nginx сканирует и прогоняет через envsubst
COPY default.conf.template /etc/nginx/templates/default.conf.template
