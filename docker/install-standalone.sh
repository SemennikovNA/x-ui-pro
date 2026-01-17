#!/bin/bash
# Автономный скрипт установки x-ui-pro через Docker Compose
# Можно запустить одной командой: curl -sSL https://raw.githubusercontent.com/.../docker/install-standalone.sh | bash -s <domain>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_inf() { echo -e "${YELLOW}[INFO]${NC} $1"; }
msg_err() { echo -e "${RED}[ERROR]${NC} $1"; }
msg_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Проверка аргументов
if [ -z "$1" ]; then
    echo "Использование: $0 <domain> [reality_domain] [timezone]"
    echo ""
    echo "Или запустите одной командой:"
    echo "  curl -sSL https://raw.githubusercontent.com/SemennikovNA/x-ui-pro/docker-compose/docker/install-standalone.sh | bash -s <domain> [reality_domain] [timezone]"
    exit 1
fi

DOMAIN="$1"
REALITY_DOMAIN="${2:-$DOMAIN}"
TZ="${3:-Asia/Almaty}"
WORK_DIR="$(pwd)/x-ui-pro-docker"
REPO_URL="${XUI_PRO_REPO_URL:-https://github.com/SemennikovNA/x-ui-pro}"
REPO_BRANCH="${XUI_PRO_REPO_BRANCH:-docker-compose}"
# Используем raw.githubusercontent.com напрямую для надежности
RAW_BASE_URL="https://raw.githubusercontent.com/SemennikovNA/x-ui-pro/${REPO_BRANCH}"

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

# Создаем рабочую директорию
msg_step "Создание рабочей директории..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
msg_ok "Рабочая директория: $WORK_DIR"

# Скачиваем необходимые файлы
msg_step "Скачивание файлов конфигурации..."

# Создаем структуру директорий
mkdir -p docker/{xui-pro/scripts,scripts}

# Функция для безопасного скачивания файла с проверкой
download_file() {
    local url="$1"
    local output="$2"
    local name="$3"
    
    msg_inf "Скачивание $name..."
    msg_inf "URL: $url"
    
    # Скачиваем файл во временный файл сначала
    local temp_file="${output}.tmp"
    
    # Используем curl с явными параметрами для raw файлов
    HTTP_CODE=$(curl -sSL -f -o "$temp_file" -w "%{http_code}" "$url" 2>&1)
    CURL_EXIT=$?
    
    # Проверяем код выхода curl
    if [ $CURL_EXIT -ne 0 ]; then
        msg_err "Ошибка curl при скачивании $name (код: $CURL_EXIT)"
        msg_inf "URL: $url"
        rm -f "$temp_file"
        return 1
    fi
    
    # Проверяем HTTP код
    if [ "$HTTP_CODE" != "200" ]; then
        msg_err "Не удалось скачать $name (HTTP код: $HTTP_CODE)"
        msg_inf "URL: $url"
        if [ -f "$temp_file" ]; then
            msg_inf "Содержимое ответа:"
            head -n 10 "$temp_file"
        fi
        rm -f "$temp_file"
        return 1
    fi
    
    # Проверяем, что файл не пустой
    if [ ! -s "$temp_file" ]; then
        msg_err "Файл $name пустой!"
        rm -f "$temp_file"
        return 1
    fi
    
    # Проверяем, что это не HTML страница ошибки
    FIRST_LINE=$(head -n 1 "$temp_file" 2>/dev/null || echo "")
    if echo "$FIRST_LINE" | grep -qE "<!DOCTYPE html>|<html|404|Not Found"; then
        msg_err "Скачанный файл $name является HTML страницей, а не скриптом!"
        msg_inf "Первая строка: $FIRST_LINE"
        msg_inf "Первые 10 строк:"
        head -n 10 "$temp_file"
        rm -f "$temp_file"
        return 1
    fi
    
    # Если все проверки пройдены, перемещаем файл на место
    mv "$temp_file" "$output"
    
    return 0
}

# Скачиваем Dockerfile
if ! download_file "${RAW_BASE_URL}/docker/xui-pro/Dockerfile" "docker/xui-pro/Dockerfile" "Dockerfile"; then
    exit 1
fi

# Скачиваем скрипты для xui-pro
for script in entrypoint.sh install-xui.sh init-xui.sh install-extras.sh; do
    if ! download_file "${RAW_BASE_URL}/docker/xui-pro/scripts/${script}" "docker/xui-pro/scripts/${script}" "$script"; then
        exit 1
    fi
    chmod +x "docker/xui-pro/scripts/${script}"
done

# Скачиваем скрипты генерации
if ! download_file "${RAW_BASE_URL}/docker/scripts/generate-nginx-configs.sh" "docker/scripts/generate-nginx-configs.sh" "generate-nginx-configs.sh"; then
    exit 1
fi
chmod +x docker/scripts/generate-nginx-configs.sh

# Скачиваем скрипт генерации docker-compose
if ! download_file "${RAW_BASE_URL}/docker/generate-docker-compose.sh" "docker/generate-docker-compose.sh" "generate-docker-compose.sh"; then
    exit 1
fi

# Дополнительная проверка для bash скрипта
if ! head -n 1 docker/generate-docker-compose.sh | grep -q "#!/bin/bash"; then
    msg_err "Файл generate-docker-compose.sh не является bash скриптом!"
    msg_inf "Первая строка: $(head -n 1 docker/generate-docker-compose.sh)"
    exit 1
fi

chmod +x docker/generate-docker-compose.sh
msg_ok "generate-docker-compose.sh скачан и проверен"

msg_ok "Файлы скачаны"

# Финальная проверка всех скачанных файлов
msg_step "Проверка скачанных файлов..."
for file in docker/xui-pro/Dockerfile docker/xui-pro/scripts/entrypoint.sh docker/xui-pro/scripts/install-xui.sh docker/xui-pro/scripts/init-xui.sh docker/xui-pro/scripts/install-extras.sh docker/scripts/generate-nginx-configs.sh docker/generate-docker-compose.sh; do
    if [ ! -f "$file" ]; then
        msg_err "Файл $file не найден!"
        exit 1
    fi
    if [ ! -s "$file" ]; then
        msg_err "Файл $file пустой!"
        exit 1
    fi
done

# Проверяем, что generate-docker-compose.sh действительно bash скрипт
if ! head -n 1 docker/generate-docker-compose.sh | grep -q "#!/bin/bash"; then
    msg_err "Файл docker/generate-docker-compose.sh не является bash скриптом!"
    msg_inf "Первые строки:"
    head -n 5 docker/generate-docker-compose.sh
    exit 1
fi

msg_ok "Все файлы проверены"

# Генерируем конфигурацию
msg_step "Генерация Docker Compose конфигурации..."
export OUTPUT_DIR="."
export TZ

# Проверяем, что мы в правильной директории
msg_inf "Текущая директория: $(pwd)"

if ! bash docker/generate-docker-compose.sh "$DOMAIN" "$REALITY_DOMAIN" "$TZ"; then
    msg_err "Ошибка при генерации конфигурации"
    msg_inf "Проверьте логи выше для деталей"
    exit 1
fi

msg_ok "Конфигурация сгенерирована"

# Сборка образов
msg_step "Сборка Docker образов (это может занять несколько минут)..."
msg_inf "Это может занять 1-2 минуты, пожалуйста, подождите..."

# Запускаем сборку с выводом в реальном времени, но проверяем код выхода
if $DOCKER_COMPOSE build 2>&1 | tee /tmp/docker-build.log; then
    BUILD_EXIT=0
else
    BUILD_EXIT=$?
fi

# Проверяем код выхода
if [ $BUILD_EXIT -ne 0 ]; then
    msg_err "Ошибка при сборке образов (код выхода: $BUILD_EXIT)"
    msg_inf "Последние строки лога сборки:"
    tail -n 30 /tmp/docker-build.log 2>/dev/null || true
    exit 1
fi

# Проверяем, что сборка действительно завершилась успешно
if grep -qE "error|Error|ERROR|failed|Failed|FAILED" /tmp/docker-build.log 2>/dev/null; then
    msg_err "Обнаружены ошибки при сборке образов"
    grep -iE "error|failed" /tmp/docker-build.log | tail -n 10
    exit 1
fi

msg_ok "Образы собраны"
rm -f /tmp/docker-build.log

# Останавливаем и удаляем существующие контейнеры, если они есть
msg_step "Проверка существующих контейнеров..."
if docker ps -a --format '{{.Names}}' | grep -qE '^(xui-pro|nginx|certbot)$'; then
    msg_inf "Обнаружены существующие контейнеры, останавливаем и удаляем..."
    $DOCKER_COMPOSE down 2>/dev/null || true
    # Также удаляем контейнеры по имени на случай, если они не в docker-compose
    docker stop xui-pro nginx certbot 2>/dev/null || true
    docker rm xui-pro nginx certbot 2>/dev/null || true
    msg_ok "Старые контейнеры удалены"
fi

# Запуск контейнеров
msg_step "Запуск контейнеров..."
msg_inf "Выполняется: $DOCKER_COMPOSE up -d"
if ! $DOCKER_COMPOSE up -d 2>&1; then
    msg_err "Ошибка при запуске контейнеров"
    msg_inf "Попробуйте запустить вручную:"
    msg_inf "  cd $WORK_DIR"
    msg_inf "  $DOCKER_COMPOSE down  # Удалить старые контейнеры"
    msg_inf "  $DOCKER_COMPOSE up -d  # Запустить новые"
    exit 1
fi
msg_ok "Команда docker-compose up -d выполнена"

# Ждем запуска
msg_inf "Ожидание запуска контейнеров (5 секунд)..."
sleep 5

# Проверяем статус контейнеров
msg_step "Проверка статуса контейнеров..."
msg_inf "Выполняется: $DOCKER_COMPOSE ps"
CONTAINER_STATUS=$($DOCKER_COMPOSE ps 2>&1 || echo "")
msg_inf "Результат проверки статуса:"
echo "$CONTAINER_STATUS"

if [ -z "$CONTAINER_STATUS" ] || ! echo "$CONTAINER_STATUS" | grep -q "xui-pro"; then
    msg_err "Контейнер xui-pro не запущен!"
    msg_inf "Статус контейнеров:"
    $DOCKER_COMPOSE ps || docker ps -a | grep xui-pro || true
    msg_inf ""
    msg_inf "Логи контейнера xui-pro:"
    $DOCKER_COMPOSE logs xui-pro 2>&1 | tail -n 50 || docker logs xui-pro 2>&1 | tail -n 50 || true
    msg_inf ""
    msg_inf "Попробуйте запустить вручную:"
    msg_inf "  cd $WORK_DIR"
    msg_inf "  $DOCKER_COMPOSE up -d"
    msg_inf "  $DOCKER_COMPOSE logs -f xui-pro"
    exit 1
fi

# Показываем статус всех контейнеров
msg_inf "Статус контейнеров:"
$DOCKER_COMPOSE ps

msg_ok "Контейнеры запущены"

# Получение сертификатов
msg_step "Проверка SSL сертификатов..."

if [ ! -d "./data/letsencrypt/live/$DOMAIN" ]; then
    msg_inf "Сертификаты не найдены. Попытка получения..."
    
    msg_inf "Ожидание готовности nginx..."
    for i in {1..30}; do
        if $DOCKER_COMPOSE ps nginx | grep -q "Up"; then
            break
        fi
        sleep 2
    done
    
    if $DOCKER_COMPOSE run --rm certbot certonly --webroot \
        --webroot-path=/var/www/certbot \
        --email "admin@${DOMAIN}" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "$REALITY_DOMAIN" 2>&1 | tee /tmp/certbot-output.log; then
        msg_ok "Сертификаты получены"
        $DOCKER_COMPOSE restart nginx
    else
        msg_err "Не удалось получить сертификаты автоматически"
        msg_inf "Вы можете получить их вручную:"
        echo "  cd $WORK_DIR"
        echo "  $DOCKER_COMPOSE run --rm certbot certonly --webroot \\"
        echo "    --webroot-path=/var/www/certbot \\"
        echo "    --email admin@${DOMAIN} \\"
        echo "    --agree-tos -d ${DOMAIN} -d ${REALITY_DOMAIN}"
    fi
else
    msg_ok "Сертификаты уже существуют"
fi

# Вывод информации
echo ""
msg_ok "Установка завершена!"
echo ""
msg_inf "Информация о доступе:"

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
fi

echo ""
msg_inf "Полезные команды:"
echo "  cd $WORK_DIR"
echo "  $DOCKER_COMPOSE logs -f          # Просмотр логов"
echo "  $DOCKER_COMPOSE down             # Остановка"
echo "  $DOCKER_COMPOSE restart          # Перезапуск"
echo "  $DOCKER_COMPOSE ps                # Статус контейнеров"
echo ""
echo "Все данные сохраняются в: $WORK_DIR/data/"
echo ""
