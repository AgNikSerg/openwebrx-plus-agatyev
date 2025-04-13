#!/bin/bash
set -e  

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'  

echo "Обновление системы и установка базовых инструментов..."
if ! command -v apt-get &> /dev/null; then
  echo -e "${RED}Ошибка: Скрипт поддерживает только системы на основе Debian/Ubuntu.${NC}"
  exit 1
fi

sudo apt-get update
sudo apt-get install -y curl git ca-certificates

echo "Настройка репозитория Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Добавление текущего пользователя в группу docker..."
sudo usermod -aG docker $USER
echo -e "${YELLOW}Важно: Для применения изменений группы 'docker', выполните перезагрузку системы или перелогиньтесь.${NC}"

echo "Настройка зеркал Docker Hub..."
sudo tee /etc/docker/daemon.json > /dev/null << EOF
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
sudo systemctl restart docker || {
  echo -e "${RED}Ошибка: Не удалось перезапустить Docker.${NC}"
  exit 1
}

echo -e "${GREEN}OK: Зеркала Docker Hub настроены:${NC}"
grep -o '"https://[^"]*"' /etc/docker/daemon.json | sed 's/"//g' | while read -r mirror; do
  echo "- $mirror"
done

echo "Создание файла блокировки модулей (/etc/modprobe.d/owrx-blacklist.conf)..."
sudo tee /etc/modprobe.d/owrx-blacklist.conf > /dev/null << _EOF_
blacklist dvb_usb_rtl28xxu
blacklist sdr_msi3101
blacklist msi001
blacklist msi2500
blacklist hackrf
_EOF_

echo -e "${GREEN}OK: Файл блокировки модулей создан:${NC}"
cat /etc/modprobe.d/owrx-blacklist.conf

echo "Клонирование репозитория openwebrx-plus-agatyev..."
git clone https://github.com/AgNikSerg/openwebrx-plus-agatyev.git

echo "Запуск Docker Compose..."
cd openwebrx-plus-agatyev || {
  echo -e "${RED}Ошибка: Не удалось перейти в директорию openwebrx-plus-agatyev.${NC}"
  exit 1
}

sudo docker compose up -d || {
  echo -e "${RED}Ошибка: Не удалось запустить Docker Compose.${NC}"
  exit 1
}

echo -e "${GREEN}Docker Compose успешно запущен в фоновом режиме.${NC}"