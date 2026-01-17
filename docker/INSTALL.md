# Установка x-ui-pro через Docker

Есть два способа установки:

## Способ 1: Быстрая установка одной командой (Рекомендуется)

Не требует клонирования репозитория. Просто выполните:

```bash
curl -sSL https://raw.githubusercontent.com/SemennikovNA/x-ui-pro/docker-compose/docker/install-standalone.sh | bash -s <ваш-домен> [reality-домен] [timezone]
```

Пример:
```bash
curl -sSL https://raw.githubusercontent.com/SemennikovNA/x-ui-pro/docker-compose/docker/install-standalone.sh | bash -s adm.duckondigitalwave.space reality.duckondigitalwave.space Asia/Almaty
```

Скрипт автоматически:
- ✅ Скачает все необходимые файлы
- ✅ Сгенерирует конфигурацию
- ✅ Соберет и запустит контейнеры
- ✅ Получит SSL сертификаты

Все файлы будут созданы в директории `./x-ui-pro-docker/` в текущей директории.

## Способ 2: Установка из клонированного репозитория

Если вы уже клонировали репозиторий:

```bash
git clone -b docker-compose https://github.com/SemennikovNA/x-ui-pro.git
cd x-ui-pro
./docker-install.sh <domain> [reality_domain] [timezone]
```

## Требования

- Docker и Docker Compose установлены
- DNS записи для доменов указывают на IP сервера
- Порты 80 и 443 открыты в firewall

## После установки

Все данные сохраняются в:
- `x-ui-pro-docker/data/xui/` - база данных x-ui
- `x-ui-pro-docker/data/letsencrypt/` - SSL сертификаты
- `x-ui-pro-docker/data/nginx-logs/` - логи nginx

Управление контейнерами:
```bash
cd x-ui-pro-docker
docker-compose logs -f    # Просмотр логов
docker-compose restart    # Перезапуск
docker-compose down       # Остановка
```
