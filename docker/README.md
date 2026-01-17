# x-ui-pro Docker Compose Setup

Этот проект предоставляет автоматическую генерацию Docker Compose конфигурации для развертывания x-ui-pro с nginx и certbot.

## Структура проекта

```
docker/
├── generate-docker-compose.sh    # Главный скрипт генерации
├── scripts/
│   ├── generate-nginx-configs.sh # Генератор nginx конфигов
│   └── get-certificates.sh       # Скрипт получения сертификатов
└── xui-pro/
    ├── Dockerfile                # Dockerfile для x-ui-pro контейнера
    └── scripts/
        ├── entrypoint.sh         # Точка входа контейнера
        ├── install-xui.sh        # Установка x-ui
        ├── init-xui.sh           # Инициализация базы данных x-ui
        └── install-extras.sh     # Установка sub2sing-box и веб-страниц
```

## Быстрый старт

### Вариант 1: Установка без клонирования репозитория (Рекомендуется)

Просто выполните одну команду:

```bash
curl -sSL https://raw.githubusercontent.com/legiz-ru/x-ui-pro/master/docker/install-standalone.sh | bash -s <domain> [reality_domain] [timezone]
```

Пример:
```bash
curl -sSL https://raw.githubusercontent.com/legiz-ru/x-ui-pro/master/docker/install-standalone.sh | bash -s adm.duckondigitalwave.space reality.duckondigitalwave.space Asia/Almaty
```

Скрипт автоматически скачает все необходимые файлы и выполнит установку.

### Вариант 2: Установка из клонированного репозитория

Если вы клонировали репозиторий:

```bash
./docker-install.sh <domain> [reality_domain] [timezone]
```

Пример:
```bash
./docker-install.sh adm.duckondigitalwave.space reality.duckondigitalwave.space Asia/Almaty
```

### Что делает скрипт автоматически:

1. ✅ Проверит зависимости (Docker, Docker Compose)
2. ✅ Сгенерирует все конфигурационные файлы
3. ✅ Соберет Docker образы
4. ✅ Запустит контейнеры
5. ✅ Получит SSL сертификаты
6. ✅ Выведет информацию о доступе

### Требования перед запуском

Убедитесь, что:
- DNS записи для ваших доменов указывают на IP сервера
- Порты 80 и 443 открыты в firewall
- Docker и Docker Compose установлены

## Ручная установка (по шагам)

Если хотите выполнить установку вручную:

### 1. Генерация конфигурации

```bash
./docker/generate-docker-compose.sh <domain> [reality_domain] [timezone]
```

Скрипт создаст директорию `docker-output/` со всеми необходимыми файлами.

### 2. Запуск

```bash
cd docker-output
docker-compose build
docker-compose up -d
```

### 3. Получение SSL сертификатов

```bash
docker-compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email admin@yourdomain.com \
    --agree-tos \
    --no-eff-email \
    -d yourdomain.com \
    -d reality.yourdomain.com

docker-compose restart nginx
```

### 4. Доступ к панели

Панель будет доступна по адресу:
```
https://yourdomain.com/<panel_path>/
```

Учетные данные и путь будут выведены после генерации конфигурации (в файле `docker-output/scripts/vars.env`).

## Компоненты

### xui-pro контейнер
- Содержит установленный x-ui
- Автоматически инициализирует базу данных при первом запуске
- Устанавливает sub2sing-box и веб-страницы подписок
- Все настройки x-ui идентичны оригинальному скрипту

### nginx контейнер
- Обрабатывает SSL терминацию
- Маршрутизирует трафик между доменами (reality и основной)
- Проксирует запросы к x-ui панели
- Обслуживает веб-страницы подписок

### certbot контейнер
- Получает и обновляет SSL сертификаты
- Сертификаты хранятся в общем volume `./data/letsencrypt`

## Настройки x-ui

Все настройки x-ui идентичны оригинальному скрипту `x-ui-pro.sh`:
- Reality на порту 8443
- WebSocket на случайном порту
- xHTTP через Unix socket
- Trojan-gRPC на случайном порту
- Случайные пути и порты для безопасности

## Структура данных

```
docker-output/
├── docker-compose.yml
├── data/
│   ├── xui/              # База данных и конфиги x-ui
│   ├── letsencrypt/      # SSL сертификаты
│   ├── certbot-www/      # ACME challenge files
│   └── nginx-logs/       # Логи nginx
├── nginx/
│   ├── nginx.conf        # Основной конфиг nginx
│   ├── conf.d/           # Конфиги виртуальных хостов
│   └── stream.d/         # Stream конфиги (для SNI routing)
└── scripts/
    └── vars.env          # Переменные окружения
```

## Обновление сертификатов

Сертификаты можно обновить вручную:
```bash
docker-compose run --rm certbot renew
docker-compose restart nginx
```

Или настроить cron для автоматического обновления.

## Устранение проблем

### Контейнер не запускается
- Проверьте логи: `docker-compose logs xui-pro`
- Убедитесь, что порты не заняты: `netstat -tulpn | grep -E '80|443'`

### Сертификаты не получаются
- Проверьте, что домены указывают на правильный IP
- Проверьте, что порт 80 доступен извне
- Проверьте логи certbot: `docker-compose logs certbot`

### Nginx не запускается
- Проверьте синтаксис: `docker-compose exec nginx nginx -t`
- Проверьте, что сертификаты существуют: `ls -la data/letsencrypt/live/`

## Примечания

- Все случайные порты и пути генерируются один раз при генерации конфигурации
- Для изменения конфигурации запустите скрипт генерации заново
- При первом запуске может потребоваться время на установку x-ui
