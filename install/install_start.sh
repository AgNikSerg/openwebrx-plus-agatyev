#!/bin/bash
set -e  

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  

get_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

DISTRO=$(get_distro)

echo "Обновление системы и установка базовых инструментов..."
if ! command -v apt-get &> /dev/null; then
  echo -e "${RED}Ошибка: Скрипт поддерживает только системы на основе Debian/Ubuntu.${NC}"
  exit 1
fi

sudo apt-get update
sudo apt-get install -y curl git  

case "$DISTRO" in
  debian)
    echo "Обнаружен Debian. Используется репозиторий Docker для Debian."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh --mirror AzureChinaCloud
    rm get-docker.sh
    ;;
  ubuntu)
    echo "Обнаружен Ubuntu. Используется репозиторий Docker для Ubuntu."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    ;;
  linuxmint)
    echo "Обнаружен Linux Mint. Используется базовая версия Ubuntu для установки Docker."
    
    echo "Установка зависимостей Docker..."
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

    # Импорт GPG ключа Docker
    echo "Импорт GPG ключа Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "Добавление репозитория Docker..."
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Обновление списка пакетов..."
    sudo apt-get update

    echo "Установка Docker..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Добавление текущего пользователя в группу docker..."
    sudo usermod -aG docker $USER
    ;;
  *)
    echo -e "${RED}Ошибка: Неподдерживаемый дистрибутив (${DISTRO}).${NC}"
    exit 1
    ;;
esac

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

BLACKLIST_FILE="/etc/modprobe.d/owrx-blacklist.conf"
echo "Создание файла блокировки модулей ($BLACKLIST_FILE)..."
cat > "$BLACKLIST_FILE" << _EOF_
blacklist dvb_usb_rtl28xxu
blacklist sdr_msi3101
blacklist msi001
blacklist msi2500
blacklist hackrf
_EOF_

if [ -f "$BLACKLIST_FILE" ]; then
  echo -e "${GREEN}OK: Файл блокировки модулей создан:${NC}"
  cat "$BLACKLIST_FILE"
else
  echo -e "${RED}Ошибка: Файл блокировки модулей (${BLACKLIST_FILE}) не найден.${NC}"
  exit 1
fi

echo "Клонирование репозитория openwebrx-plus-agatyev..."
git clone https://github.com/AgNikSerg/openwebrx-plus-agatyev.git || (
  echo -e "${RED}Ошибка: Не удалось клонировать репозиторий.${NC}"
  exit 1
)

echo "Переход в директорию openwebrx-plus-agatyev..."
cd openwebrx-plus-agatyev || (
  echo -e "${RED}Ошибка: Не удалось перейти в директорию openwebrx-plus-agatyev.${NC}"
  exit 1
)

echo "Запуск Docker Compose..."
sudo docker compose up -d || (
  echo -e "${RED}Ошибка: Не удалось запустить Docker Compose.${NC}"
  exit 1
)

echo -e "${GREEN}Docker Compose успешно запущен в фоновом режиме.${NC}"