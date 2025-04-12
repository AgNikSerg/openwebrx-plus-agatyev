#!/bin/bash
set -e  

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  

echo "Обновление системы и установка базовых инструментов..."
if ! command -v apt-get &> /dev/null; then
  echo -e "${RED}Ошибка: Скрипт поддерживает только системы на основе Debian/Ubuntu.${NC}"
  exit 1
fi

sudo apt-get update
sudo apt-get install -y curl jq systemd

echo "Загрузка и установка Docker через официальный скрипт..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh  

echo "Настройка зеркал Docker Hub..."
cat << EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "registry-mirrors": [
    "https://dockerhub.timeweb.cloud",
    "https://mirror.gcr.io",
    "https://c.163.com",
    "https://registry.docker-cn.com",
    "https://daocloud.io"
  ]
}
EOF

echo "Перезапуск Docker..."
sudo systemctl restart docker || (
  echo -e "${RED}Ошибка: Не удалось перезапустить Docker.${NC}"
  exit 1
)

CONFIG_FILE="/etc/docker/daemon.json"
if [ -f "$CONFIG_FILE" ]; then
  echo -e "${GREEN}OK: Зеркала Docker Hub настроены:${NC}"
  grep -o '"https://[^"]*"' "$CONFIG_FILE" | sed 's/"//g' | while read -r mirror; do
    echo "- $mirror"
  done
else
  echo -e "${RED}Ошибка: Файл конфигурации Docker (${CONFIG_FILE}) не найден.${NC}"
  exit 1
fi

if systemctl is-active --quiet docker; then
  echo -e "${GREEN}Служба Docker запущена.${NC}"
else
  echo -e "${RED}Ошибка: Служба Docker не запущена.${NC}"
  exit 1
fi