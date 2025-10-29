# Docker Manager v2.0

Расширенный менеджер Docker контейнеров, образов и компоновок с поддержкой мониторинга, бэкапов и автоматизации.

## Особенности

- 🐳 **Комплексное управление** - контейнеры, образы, volumes, сети
- 📊 **Детальный мониторинг** - статистика использования ресурсов в реальном времени
- 💾 **Умные бэкапы** - комплексное резервное копирование с метаданными
- 🔄 **Восстановление** - восстановление контейнеров из бэкапов
- 🧹 **Интеллектуальная очистка** - автоматическое обслуживание системы
- 📈 **Сбор метрик** - отслеживание операций и производительности
- 🚀 **Docker Compose** - управление многоконтейнерными приложениями
- 🛡️ **Безопасность** - проверки и валидации операций

## Использование

```bash
# Детальный список контейнеров
./scripts/docker-manager.sh ps

# Детальная статистика
./scripts/docker-manager.sh stats

# Умный просмотр логов
./scripts/docker-manager.sh logs nginx 100

# Комплексный бэкап
./scripts/docker-manager.sh backup mysql

# Восстановление из бэкапа
./scripts/docker-manager.sh restore backups/mysql_backup

# Расширенный мониторинг
./scripts/docker-manager.sh monitor

# Управление Compose проектом
./scripts/docker-manager.sh compose ./myapp up

Команды
Управление контейнерами
ps - Детальный список контейнеров

Показывает запущенные и остановленные контейнеры с подробной информацией.

Пример вывода:
text

📊 Общая статистика:
  🟢 Запущено: 3
  🔴 Остановлено: 2
  📦 Всего: 5

🟢 ЗАПУЩЕННЫЕ КОНТЕЙНЕРЫ:
NAMES     IMAGE          STATUS       PORTS                     RUNNING FOR
nginx     nginx:latest   Up 2 hours   0.0.0.0:80->80/tcp       2 hours
mysql     mysql:8.0      Up 2 hours   3306/tcp, 33060/tcp      2 hours

logs <container> [lines] [follow] - Умный просмотр логов

Просмотр логов контейнера с поддержкой пагинации и режима реального времени.

Примеры:
bash

# Последние 50 строк
./scripts/docker-manager.sh logs nginx

# Последние 100 строк
./scripts/docker-manager.sh logs nginx 100

# Режим реального времени
./scripts/docker-manager.sh logs nginx 50 true

Управление состоянием

    start <container> - Запуск контейнера

    stop <container> - Остановка контейнера

    restart <container> - Перезапуск контейнера

    remove <container> - Удаление контейнера

Управление образами
images - Детальный список образов

Отображает все Docker образы с информацией о размерах и датах создания.
Мониторинг и аналитика
stats - Детальная статистика

Показывает использование CPU, памяти, сети и дисковых операций.

Пример вывода:
text

📈 РЕАЛЬНАЯ СТАТИСТИКА ИСПОЛЬЗОВАНИЯ:
NAME    CPU %   MEM USAGE / LIMIT   MEM %   NET I/O       BLOCK I/O   PIDS
nginx   0.15%   25MiB / 1.94GiB     1.26%   1.45kB/2.89kB 0B/0B       2
mysql   1.23%   350MiB / 1.94GiB    17.63%  1.2MB/4.5MB   0B/16.4kB   30

💾 ИСПОЛЬЗОВАНИЕ ДИСКА DOCKER:
TYPE            TOTAL   ACTIVE   SIZE      RECLAIMABLE
Images          5       3        1.24GB    610.7MB (49%)
Containers      3       3        62B       0B (0%)
Local Volumes   4       3        420.4MB   125.2MB (29%)
Build Cache     0       0        0B        0B

monitor - Расширенный мониторинг

Режим реального времени с автоматическим обновлением статистики.
Бэкапы и восстановление
backup <container> [name] - Комплексный бэкап

Создает полный бэкап контейнера включая:

    Экспорт контейнера

    Метаданные (inspect)

    Последние логи

    Volumes (опционально)

    Манифест бэкапа

Пример:
bash

./scripts/docker-manager.sh backup mysql database_backup_20251028

restore <path> [name] - Восстановление

Восстанавливает контейнер из ранее созданного бэкапа.
Docker Compose
compose <path> [action] - Управление проектами

Полная поддержка Docker Compose проектов:

Действия:

    ps - статус сервисов

    up - запуск проекта

    down - остановка проекта

    restart - перезапуск

    logs - логи в реальном времени

    stop - остановка сервисов

    start - запуск сервисов

    build - пересборка образов

Примеры:
bash

# Запуск проекта
./scripts/docker-manager.sh compose ./myapp up

# Просмотр статуса
./scripts/docker-manager.sh compose ./myapp ps

# Логи в реальном времени
./scripts/docker-manager.sh compose ./myapp logs

Системное обслуживание
cleanup - Расширенная очистка

Интеллектуальная очистка Docker системы:

    Остановка контейнеров (с исключениями)

    Удаление остановленных контейнеров

    Очистка неиспользуемых образов

    Удаление неиспользуемых volumes и сетей

    Очистка builder cache

metrics - Просмотр метрик

Статистика операций выполненных через менеджер.
Конфигурация

Создайте конфигурационный файл:
bash

./scripts/docker-manager.sh config

Редактируйте configs/docker-manager.conf:
bash

# Автоматическое управление
AUTO_REMOVE_STOPPED_CONTAINERS=false
AUTO_REMOVE_DANGLING_IMAGES=false
AUTO_UPDATE_CONTAINERS=false

# Настройки бэкапа
BACKUP_PATH="/home/defo/projects/system-admin/docker-backups"
BACKUP_RETENTION_DAYS=7
ENABLE_VOLUME_BACKUP=true

# Мониторинг
MONITOR_INTERVAL=5
ENABLE_METRICS_COLLECTION=true
METRICS_RETENTION_DAYS=30

# Безопасность
ENABLE_SECURITY_SCAN=false
SCAN_VULNERABILITIES=false

# Контейнеры для исключения (через пробел)
EXCLUDE_CONTAINERS=""

# Приоритетные контейнеры (запускаются первыми)
PRIORITY_CONTAINERS="database redis"

# Docker Compose проекты
COMPOSE_PROJECTS=(
    "/path/to/project1/docker-compose.yml"
    "/path/to/project2/docker-compose.yml"
)

# Настройки ресурсов
CPU_LIMIT=""
MEMORY_LIMIT=""
RESTART_POLICY="unless-stopped"

# Уведомления
ENABLE_NOTIFICATIONS=false
NOTIFICATION_METHOD="log"

Примеры использования
Мониторинг производительности
bash

# Запуск мониторинга в реальном времени
./scripts/docker-manager.sh monitor

Резервное копирование критических контейнеров
bash

# Бэкап базы данных
./scripts/docker-manager.sh backup mysql

# Бэкап веб-сервера
./scripts/docker-manager.sh backup nginx

# Бэкап с кастомным именем
./scripts/docker-manager.sh backup redis redis_backup_$(date +%Y%m%d)

Восстановление после сбоя
bash

# Восстановление базы данных
./scripts/docker-manager.sh restore backups/mysql_backup_20251028 restored_mysql

# Проверка восстановленного контейнера
./scripts/docker-manager.sh ps
./scripts/docker-manager.sh logs restored_mysql

Управление приложениями Docker Compose
bash

# Развертывание приложения
./scripts/docker-manager.sh compose ./my-app up

# Мониторинг состояния
./scripts/docker-manager.sh compose ./my-app ps

# Просмотр логов
./scripts/docker-manager.sh compose ./my-app logs

# Остановка приложения
./scripts/docker-manager.sh compose ./my-app down

Регулярное обслуживание
bash

# Еженедельная очистка
./scripts/docker-manager.sh cleanup

# Проверка состояния системы
./scripts/docker-manager.sh stats

# Просмотр метрик использования
./scripts/docker-manager.sh metrics

Файлы и директории
Бэкапы

    Директория: docker-backups/

    Формат: container_backup_YYYYMMDD_HHMMSS/

    Содержимое:

        container.tar.gz - экспорт контейнера

        inspect.json - метаданные

        last_logs.log - логи

        volume_*.tar.gz - бэкапы volumes

        manifest.txt - описание бэкапа

Логи

    Файл: logs/docker-manager.log

    Формат: [timestamp] [level] [action] message

Метрики

    Файл: metrics/docker-metrics-YYYYMMDD.csv

    Формат: timestamp,action,container,result

Конфигурация

    Файл: configs/docker-manager.conf

Зависимости
Обязательные

    Docker - система контейнеризации

    Bash 4.0+ - оболочка выполнения

Опциональные

    docker-compose или docker compose - для управления компоновками

    gzip - для сжатия бэкапов

    jq - для обработки JSON (рекомендуется)

Автоматизация
Cron задачи для регулярных операций
bash

# Ежедневный бэкап в 2:00
0 2 * * * /path/to/system-admin/scripts/docker-manager.sh backup mysql

# Еженедельная очистка в воскресенье в 3:00
0 3 * * 0 /path/to/system-admin/scripts/docker-manager.sh cleanup

# Ежечасный мониторинг состояния
0 * * * * /path/to/system-admin/scripts/docker-manager.sh stats

Systemd службы для критических контейнеров
ini

[Unit]
Description=My Application
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/path/to/system-admin/scripts/docker-manager.sh start myapp
ExecStop=/path/to/system-admin/scripts/docker-manager.sh stop myapp

[Install]
WantedBy=multi-user.target

Совместимость

    ✅ Docker версии: 20.10+, 23.0+, 24.0+

    ✅ Docker Compose: v1, v2 (совместимость с обоими)

    ✅ Платформы: Linux, macOS, WSL2

    ✅ Архитектуры: x86_64, ARM64

    ✅ Файловые системы: overlay2, aufs, btrfs, zfs

Безопасность

    🔒 Проверка прав - автоматическая валидация доступа к Docker

    🚫 Исключения - защита критических контейнеров от случайного удаления

    📝 Подробное логирование - аудит всех операций

    💾 Бэкапы метаданных - сохранение конфигураций контейнеров

Диагностика проблем
Проблемы с производительностью
bash

# Мониторинг ресурсов
./scripts/docker-manager.sh monitor

# Детальная статистика
./scripts/docker-manager.sh stats

# Анализ использования диска
./scripts/docker-manager.sh cleanup

Проблемы с контейнерами
bash

# Просмотр логов
./scripts/docker-manager.sh logs problem_container 100

# Проверка состояния
./scripts/docker-manager.sh ps

# Перезапуск контейнера
./scripts/docker-manager.sh restart problem_container

Восстановление после сбоя
bash

# Восстановление из бэкапа
./scripts/docker-manager.sh restore backup_path

# Проверка восстановления
./scripts/docker-manager.sh ps
./scripts/docker-manager.sh logs restored_container

Автор

g1if

Примечание: Все операции с контейнерами безопасны благодаря проверкам и валидациям. Система предоставляет комплексное управление Docker окружением с поддержкой бэкапов, мониторинга и автоматизации.
text


## 🚀 **ОСНОВНЫЕ УЛУЧШЕНИЯ В ВЕРСИИ 2.0**

1. ✅ **Проверка зависимостей** - автоматическая валидация Docker окружения
2. ✅ **Расширенная конфигурация** - настраиваемые параметры и исключения
3. ✅ **Комплексные бэкапы** - экспорт контейнеров + метаданные + volumes
4. ✅ **Восстановление** - полное восстановление контейнеров из бэкапов
5. ✅ **Сбор метрик** - отслеживание всех операций менеджера
6. ✅ **Улучшенный мониторинг** - детальная статистика в реальном времени
7. ✅ **Docker Compose v2** - поддержка современных версий Compose
8. ✅ **Безопасность** - проверки прав и защита от случайных удалений
