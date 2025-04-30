#!/bin/bash
if [ "$(uname)" = "Linux" ]; then
  mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  # 2GB（= 2 * 1024 * 1024 KB）以下ならPlaywrightをdisable
  if [ "$mem_total" -le $((2 * 1024 * 1024)) ]; then
    DISABLE_PLAYWRIGHT=1
    export DISABLE_PLAYWRIGHT
  fi
fi

if [ ! -f "env.txt" ]; then
    echo "craete env.txt"
    exit 1
fi
docker compose down
docker compose run --rm app00 rm -f tmp/pids/server.pid
docker compose run --rm app01 rm -f tmp/pids/server.pid
docker compose run --rm app02 rm -f tmp/pids/server.pid
docker compose run --rm app03 rm -f tmp/pids/server.pid

if [ "$1" = "clean" ]; then
    exit 0
fi

docker compose up db -d
until docker exec sample-db mysqladmin ping -h 127.0.0.1 -u root -pmysql --silent; do
  echo "Waiting for MySQL..."
  sleep 2
done
echo "MySQL is ready!"
docker compose run --rm prepare bin/rails db:prepare
docker compose up -d
docker compose down prepare
echo "Demo is running..."
