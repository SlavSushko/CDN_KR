#!/usr/bin/env bash
set -euo pipefail

IMAGE=${1:-cdn-edge:local}

echo "== Test edge image (nginx syntax) : $IMAGE =="

# nginx -t can be executed inside a container
docker run --rm $IMAGE nginx -t -c /etc/nginx/conf.d/default.conf
echo "Edge nginx syntax OK"
