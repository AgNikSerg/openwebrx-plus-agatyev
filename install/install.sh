#!/bin/bash
set -e  # Прерывать выполнение при ошибке

# --- Установка Docker ---
echo "Добавление репозитория Docker и установка пакетов..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl jq

# Добавление GPG-ключа Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Добавление репозитория в sources.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- Настройка зеркал Docker Hub ---
echo "Настройка зеркал Docker Hub..."

# Список зеркал
MIRRORS=(
  "https://dockerhub.timeweb.cloud"
  "https://mirror.gcr.io"
  "https://c.163.com"
  "https://registry.docker-cn.com"
  "https://daocloud.io"
)

# Проверка существования файла daemon.json
CONFIG_FILE="/etc/docker/daemon.json"
if [ -f "$CONFIG_FILE" ]; then
  # Используем jq для добавления зеркал без перезаписи конфига
  echo "Обновление существующего файла $CONFIG_FILE..."
  sudo jq --argjson mirrors "$(jq -n '$ARGS.positional' --args "${MIRRORS[@]}")" '.registry-mirrors = $mirrors' "$CONFIG_FILE" | sudo tee "$CONFIG_FILE" > /dev/null
else
  # Создаем новый файл с зеркалами
  echo "Создание нового файла $CONFIG_FILE..."
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
{
  "registry-mirrors": ["${MIRRORS[@]}"]
}
EOF
fi

# Перезапуск Docker
echo "Перезапуск Docker..."
sudo systemctl restart docker

echo "Docker установлен и настроен с зеркалами!"