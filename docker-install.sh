#!/bin/bash
# Главный скрипт для установки x-ui-pro через Docker Compose
# Использование: ./docker-install.sh <domain> [reality_domain] [timezone]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_inf() { echo -e "${YELLOW}[INFO]${NC} $1"; }
msg_err() { echo -e "${RED}[ERROR]${NC} $1"; }
msg_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Проверка аргументов
if [ -z "$1" ]; then
    echo "Использование: $0 <domain> [reality_domain] [timezone]"
    echo ""
    echo "Примеры:"
    echo "  $0 adm.duckondigitalwave.space"
    echo "  $0 adm.duckondigitalwave.space reality.duckondigitalwave.space"
    echo "  $0 adm.duckondigitalwave.space reality.duckondigitalwave.space Asia/Almaty"
    exit 1
fi

DOMAIN="$1"
REALITY_DOMAIN="${2:-$DOMAIN}"
TZ="${3:-Asia/Almaty}"
OUTPUT_DIR="./docker-output"

# Проверка зависимостей
msg_step "Проверка зависимостей..."
if ! command -v docker &> /dev/null; then
    msg_err "Docker не установлен. Установите Docker и попробуйте снова."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    msg_err "Docker Compose не установлен. Установите Docker Compose и попробуйте снова."
    exit 1
fi

# Определяем команду docker compose
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

msg_ok "Зависимости проверены"

# Шаг 1: Генерация конфигурации
msg_step "Генерация Docker Compose конфигурации..."
export OUTPUT_DIR
export TZ
if ! bash ./docker/generate-docker-compose.sh "$DOMAIN" "$REALITY_DOMAIN" "$TZ"; then
    msg_err "Ошибка при генерации конфигурации"
    exit 1
fi

msg_ok "Конфигурация сгенерирована в директории: $OUTPUT_DIR"

# Шаг 2: Переход в директорию
cd "$OUTPUT_DIR"

# Шаг 3: Сборка образов
msg_step "Сборка Docker образов (это может занять несколько минут)..."
if ! $DOCKER_COMPOSE build; then
    msg_err "Ошибка при сборке образов"
    exit 1
fi
msg_ok "Образы собраны"

# Шаг 4: Запуск контейнеров
msg_step "Запуск контейнеров..."
if ! $DOCKER_COMPOSE up -d; then
    msg_err "Ошибка при запуске контейнеров"
    exit 1
fi
msg_ok "Контейнеры запущены"

# Ждем запуска контейнеров
msg_inf "Ожидание запуска контейнеров..."
sleep 5

# Шаг 5: Получение сертификатов
msg_step "Проверка SSL сертификатов..."

if [ ! -d "./data/letsencrypt/live/$DOMAIN" ]; then
    msg_inf "Сертификаты не найдены. Попытка получения..."
    
    # Ждем пока nginx запустится
    msg_inf "Ожидание готовности nginx..."
    for i in {1..30}; do
        if $DOCKER_COMPOSE ps nginx | grep -q "Up"; then
            break
        fi
        sleep 2
    done
    
    # Получаем сертификаты
    if $DOCKER_COMPOSE run --rm certbot certonly --webroot \
        --webroot-path=/var/www/certbot \
        --email "admin@${DOMAIN}" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "$REALITY_DOMAIN" 2>&1 | tee /tmp/certbot-output.log; then
        msg_ok "Сертификаты получены"
        
        # Перезапускаем nginx
        msg_inf "Перезапуск nginx с новыми сертификатами..."
        $DOCKER_COMPOSE restart nginx
    else
        msg_err "Не удалось получить сертификаты автоматически"
        msg_inf "Вы можете получить их вручную командой:"
        echo "  cd $OUTPUT_DIR"
        echo "  $DOCKER_COMPOSE run --rm certbot certonly --webroot \\"
        echo "    --webroot-path=/var/www/certbot \\"
        echo "    --email admin@${DOMAIN} \\"
        echo "    --agree-tos -d ${DOMAIN} -d ${REALITY_DOMAIN}"
    fi
else
    msg_ok "Сертификаты уже существуют"
fi

# Шаг 6: Вывод информации
echo ""
msg_ok "Установка завершена!"
echo ""
msg_inf "Информация о доступе:"

# Читаем учетные данные из vars.env если есть
if [ -f "./scripts/vars.env" ]; then
    source ./scripts/vars.env
    echo ""
    echo "  Панель управления:"
    echo "    URL: https://${DOMAIN}/${panel_path}/"
    echo "    Username: ${config_username}"
    echo "    Password: ${config_password}"
    echo ""
    echo "  Веб-страница подписок:"
    echo "    URL: https://${DOMAIN}/${web_path}?name=first"
    echo ""
    echo "  sub2sing-box:"
    echo "    URL: https://${DOMAIN}/${sub2singbox_path}/"
    echo ""
else
    echo ""
    echo "  Проверьте файл ./scripts/vars.env для учетных данных"
fi

echo ""
msg_inf "Полезные команды:"
echo "  Просмотр логов:        $DOCKER_COMPOSE logs -f"
echo "  Остановка:             $DOCKER_COMPOSE down"
echo "  Перезапуск:            $DOCKER_COMPOSE restart"
echo "  Статус контейнеров:    $DOCKER_COMPOSE ps"
echo ""
echo "Все данные сохраняются в директории: $OUTPUT_DIR/data/"
echo ""
