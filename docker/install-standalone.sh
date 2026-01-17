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

# Скачиваем Dockerfile
msg_inf "Скачивание Dockerfile..."
curl -sSL "${REPO_URL}/raw/${REPO_BRANCH}/docker/xui-pro/Dockerfile" -o docker/xui-pro/Dockerfile || {
    msg_err "Не удалось скачать Dockerfile. Проверьте доступность репозитория."
    exit 1
}

# Скачиваем скрипты для xui-pro
for script in entrypoint.sh install-xui.sh init-xui.sh install-extras.sh; do
    msg_inf "Скачивание $script..."
    curl -sSL "${REPO_URL}/raw/${REPO_BRANCH}/docker/xui-pro/scripts/${script}" -o "docker/xui-pro/scripts/${script}" || {
        msg_err "Не удалось скачать ${script}"
        exit 1
    }
    chmod +x "docker/xui-pro/scripts/${script}"
done

# Скачиваем скрипты генерации
msg_inf "Скачивание скриптов генерации..."
curl -sSL "${REPO_URL}/raw/${REPO_BRANCH}/docker/scripts/generate-nginx-configs.sh" -o docker/scripts/generate-nginx-configs.sh || {
    msg_err "Не удалось скачать generate-nginx-configs.sh"
    exit 1
}
chmod +x docker/scripts/generate-nginx-configs.sh

# Скачиваем скрипт генерации docker-compose
msg_inf "Скачивание generate-docker-compose.sh..."
GEN_COMPOSE_URL="${REPO_URL}/raw/${REPO_BRANCH}/docker/generate-docker-compose.sh"
msg_inf "URL: $GEN_COMPOSE_URL"
if ! curl -sSL "$GEN_COMPOSE_URL" -o docker/generate-docker-compose.sh; then
    msg_err "Не удалось скачать generate-docker-compose.sh"
    msg_inf "Проверьте доступность URL: $GEN_COMPOSE_URL"
    exit 1
fi

# Проверяем, что файл действительно bash скрипт, а не HTML
if ! head -n 1 docker/generate-docker-compose.sh | grep -q "#!/bin/bash"; then
    msg_err "Скачанный файл не является bash скриптом. Возможно, неправильный путь в репозитории."
    msg_inf "Первые строки скачанного файла:"
    head -n 10 docker/generate-docker-compose.sh
    msg_inf "Проверьте, что файл существует по пути: docker/generate-docker-compose.sh в ветке ${REPO_BRANCH}"
    exit 1
fi

chmod +x docker/generate-docker-compose.sh

msg_ok "Файлы скачаны"

# Генерируем конфигурацию
msg_step "Генерация Docker Compose конфигурации..."
export OUTPUT_DIR="."
export TZ

# Проверяем наличие скрипта перед запуском
if [ ! -f "docker/generate-docker-compose.sh" ]; then
    msg_err "Файл docker/generate-docker-compose.sh не найден"
    exit 1
fi

# Проверяем, что мы в правильной директории
msg_inf "Текущая директория: $(pwd)"
msg_inf "Содержимое docker/:"
ls -la docker/ || true

if ! bash docker/generate-docker-compose.sh "$DOMAIN" "$REALITY_DOMAIN" "$TZ"; then
    msg_err "Ошибка при генерации конфигурации"
    exit 1
fi

msg_ok "Конфигурация сгенерирована"

# Сборка образов
msg_step "Сборка Docker образов (это может занять несколько минут)..."
if ! $DOCKER_COMPOSE build; then
    msg_err "Ошибка при сборке образов"
    exit 1
fi
msg_ok "Образы собраны"

# Запуск контейнеров
msg_step "Запуск контейнеров..."
if ! $DOCKER_COMPOSE up -d; then
    msg_err "Ошибка при запуске контейнеров"
    exit 1
fi
msg_ok "Контейнеры запущены"

# Ждем запуска
msg_inf "Ожидание запуска контейнеров..."
sleep 5

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
