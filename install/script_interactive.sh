#!/bin/bash
set -e  

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_DIR="$HOME/openwebrx-plus-agatyev"

if [ ! -f "/usr/local/bin/sdr" ]; then
  echo -e "${YELLOW}Создание символической ссылки для команды 'sdr'...${NC}"
  sudo ln -sf "$(pwd)/install_sdr.sh" /usr/local/bin/sdr || { echo -e "${RED}Ошибка: Не удалось создать символическую ссылку.${NC}"; exit 1; }
  echo -e "${GREEN}Теперь вы можете запускать скрипт командой 'sdr'.${NC}"
fi


confirm_action() {
  read -p "Вы уверены, что хотите продолжить? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}Действие отменено.${NC}"
    return 1
  fi
  return 0
}

install_web_sdr() {
  echo -e "${GREEN}=== Установка всего для WEB SDR ===${NC}"
  echo "Будут установлены следующие компоненты:"
  echo "- Docker и связанные пакеты (docker-ce, docker-compose-plugin)"
  echo "- Настройка зеркал реестра Docker"
  echo "- Блокировка конфликтующих модулей ядра"
  echo "- Клонирование репозитория OpenWebRX"
  echo "- Создание необходимых директорий"

  if ! confirm_action; then
    return
  fi

  sudo apt-get update || { echo -e "${RED}Ошибка: Не удалось обновить список пакетов.${NC}"; return 1; }
  sudo apt-get install -y curl git ca-certificates || { echo -e "${RED}Ошибка: Не удалось установить зависимости.${NC}"; return 1; }

  echo -e "${YELLOW}Установка Docker...${NC}"
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || { echo -e "${RED}Ошибка: Не удалось скачать ключ Docker.${NC}"; return 1; }
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update || { echo -e "${RED}Ошибка: Не удалось обновить список пакетов.${NC}"; return 1; }
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo -e "${RED}Ошибка: Не удалось установить Docker.${NC}"; return 1; }

  sudo usermod -aG docker $USER
  echo -e "${YELLOW}Важно: Для применения изменений группы 'docker', выполните перезагрузку системы или перелогиньтесь.${NC}"

  echo -e "${YELLOW}Настройка Docker (зеркала реестра)...${NC}"
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

  sudo systemctl restart docker || { echo -e "${RED}Ошибка: Не удалось перезапустить Docker.${NC}"; return 1; }

  echo -e "${YELLOW}Блокировка конфликтующих модулей ядра...${NC}"
  sudo tee /etc/modprobe.d/owrx-blacklist.conf > /dev/null << _EOF_
blacklist dvb_usb_rtl28xxu
blacklist sdr_msi3101
blacklist msi001
blacklist msi2500
blacklist hackrf
_EOF_

  echo -e "${YELLOW}Создание директорий для OpenWebRX...${NC}"
  sudo mkdir -p /opt/owrx-docker/var /opt/owrx-docker/etc /opt/owrx-docker/plugins/receiver /opt/owrx-docker/plugins/map

  echo -e "${YELLOW}Клонирование репозитория OpenWebRX...${NC}"
  git clone https://github.com/AgNikSerg/openwebrx-plus-agatyev.git "$REPO_DIR" || { echo -e "${RED}Ошибка: Не удалось клонировать репозиторий.${NC}"; return 1; }
  cd "$REPO_DIR" || { echo -e "${RED}Ошибка: Не удалось перейти в директорию репозитория.${NC}"; return 1; }
  echo -e "${GREEN}WEB SDR успешно установлен.${NC}"
}

uninstall_web_sdr() {
  echo -e "${GREEN}=== Удаление всего для WEB SDR ===${NC}"
  echo "Будут удалены следующие компоненты:"
  echo "- Docker и связанные пакеты"
  echo "- Настройки Docker (зеркала реестра)"
  echo "- Блокировка модулей ядра"
  echo "- Директории OpenWebRX"
  echo "- Репозиторий OpenWebRX"

  if ! confirm_action; then
    return
  fi

  echo -e "${YELLOW}Остановка Docker Compose...${NC}"
  sudo docker compose down || echo -e "${YELLOW}Предупреждение: Docker Compose не был запущен.${NC}"

  echo -e "${YELLOW}Удаление пользователя из группы docker...${NC}"
  sudo deluser $USER docker || echo -e "${RED}Ошибка: Не удалось удалить пользователя из группы docker.${NC}"
  
  echo -e "${YELLOW}Удаление Docker...${NC}"
  sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo -e "${RED}Ошибка: Не удалось удалить Docker.${NC}"; return 1; }

  echo -e "${YELLOW}Удаление настроек Docker...${NC}"
  sudo rm -f /etc/docker/daemon.json

  echo -e "${YELLOW}Удаление блокировки модулей ядра...${NC}"
  sudo rm -f /etc/modprobe.d/owrx-blacklist.conf

  echo -e "${YELLOW}Удаление директорий OpenWebRX...${NC}"
  sudo rm -rf /opt/owrx-docker openwebrx-plus-agatyev

  echo -e "${YELLOW}Удаление ключа Docker...${NC}"
  sudo rm -f /etc/apt/keyrings/docker.asc

  echo -e "${YELLOW}Удаление списка Docker...${NC}"
  sudo rm -f /etc/apt/sources.list.d/docker.list

  echo -e "${GREEN}WEB SDR полностью удален из системы.${NC}"
}

start_web_sdr() {
  echo -e "${GREEN}=== Запуск WEB SDR ===${NC}"

  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Ошибка: Docker не установлен.${NC}"
    echo -e "${YELLOW}Пожалуйста, выполните шаг 1 для установки всех необходимых компонентов.${NC}"
    return
  fi

# Проверяем запущенные контейнеры через Docker
if sudo docker ps | grep -q "openwebrx"; then
  echo -e "${YELLOW}WEB SDR уже запущен:${NC}"
  sudo docker ps --filter name=openwebrx
  return
fi

  if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}Ошибка: Репозиторий OpenWebRX не найден.${NC}"
    echo -e "${YELLOW}Пожалуйста, выполните шаг 1 для клонирования репозитория.${NC}"
    return
  fi

  cd "$REPO_DIR" || { echo -e "${RED}Ошибка: Не удалось перейти в директорию репозитория.${NC}"; return; }
  
  if sudo docker compose ps | grep -q "running"; then
    echo -e "${YELLOW}WEB SDR уже запущен.${NC}"
    return
  fi

  echo -e "${YELLOW}Запуск Docker Compose...${NC}"
  sudo docker compose up -d || { echo -e "${RED}Ошибка: Не удалось запустить Docker Compose.${NC}"; return; }

  echo -e "${GREEN}WEB SDR успешно запущен.${NC}"
}

stop_web_sdr() {
  echo -e "${GREEN}=== Остановка WEB SDR ===${NC}"
  if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR" || { echo -e "${RED}Ошибка: Не удалось перейти в директорию репозитория.${NC}"; return 1; }
    sudo docker compose down || echo -e "${YELLOW}Предупреждение: Docker Compose уже остановлен.${NC}"
    echo -e "${GREEN}WEB SDR успешно остановлен.${NC}"
  else
    echo -e "${RED}Ошибка: Репозиторий OpenWebRX не найден.${NC}"
  fi
}

show_menu() {
  echo -e "${GREEN}=== Главное меню ===${NC}"
  echo "1. Установить всё для WEB SDR"
  echo "2. Удалить всё для WEB SDR"
  echo "3. Запустить WEB SDR"
  echo "4. Остановить WEB SDR"
  echo "5. Выйти"
  echo -n "Выберите действие (1-5): "
}

while true; do
  show_menu
  read -r choice

  case $choice in
    1)
      install_web_sdr
      ;;
    2)
      uninstall_web_sdr
      ;;
    3)
      start_web_sdr
      ;;
    4)
      stop_web_sdr
      ;;
    5)
      echo -e "${YELLOW}Выход из программы.${NC}"
      break
      ;;
    *)
      echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
      ;;
  esac
done