# Service Manager v2.0

Продвинутый менеджер системных сервисов с расширенным мониторингом, авто-восстановлением и генерацией отчетов.

## Особенности

- 🚀 **Мульти-системная поддержка** - systemd, sysvinit, OpenRC
- 📊 **Расширенный мониторинг** - реальное время с цветовой индикацией
- 🔄 **Авто-восстановление** - автоматические попытки перезапуска сбоящих сервисов
- 📈 **Детальная аналитика** - использование ресурсов, логи, метрики
- 🚨 **Умные оповещения** - консоль, логи, email, telegram
- 📋 **Генерация отчетов** - автоматические и ручные отчеты состояния
- 🛡️ **Валидация сервисов** - проверка существования и корректности
- 🔍 **Расширенная диагностика** - анализ логов, поиск проблем

## Использование

```bash
# Основной анализ системы
./scripts/service-manager.sh

# Мониторинг в реальном времени
./scripts/service-manager.sh monitor

# Управление сервисами
./scripts/service-manager.sh start nginx
./scripts/service-manager.sh stop apache2
./scripts/service-manager.sh restart mysql

# Диагностика и логи
./scripts/service-manager.sh logs ssh 50
./scripts/service-manager.sh recover docker

# Списки и отчеты
./scripts/service-manager.sh list
./scripts/service-manager.sh report
./scripts/service-manager.sh validate nginx

# Конфигурация
./scripts/service-manager.sh config

Поддерживаемые системы инициализации
🔧 Systemd (Ubuntu 16.04+, Debian 8+, CentOS 7+)

    Полная поддержка всех операций

    Детальная информация о сервисах

    Мониторинг использования ресурсов

⚙️ SysV Init (Ubuntu 14.04, Debian 7, CentOS 6)

    Базовые операции управления

    Статус сервисов

    Ограниченная диагностика

🐧 OpenRC (Gentoo, Alpine Linux)

    Базовое управление сервисами

    Проверка статуса

    Совместимость с основными командами

Конфигурация

Создайте конфигурационный файл:
bash

./scripts/service-manager.sh config

Редактируйте configs/service-manager.conf:
bash

# Критические сервисы для мониторинга
CRITICAL_SERVICES=("ssh" "nginx" "mysql" "postgresql" "docker" "apache2")

# Настройки мониторинга
MONITOR_REFRESH_RATE=5
MONITOR_TIMEOUT=300
MAX_RESTART_ATTEMPTS=3
RESTART_DELAY=5

# Настройки оповещений
ALERT_ENABLED=true
ALERT_METHODS=("console" "log")

# Авто-восстановление
ENABLE_AUTO_RECOVERY=true

# Отчеты
AUTO_GENERATE_REPORT=true
REPORT_RETENTION_DAYS=7

Мониторинг в реальном времени
bash

# Мониторинг с настройками по умолчанию
./scripts/service-manager.sh monitor

# Кастомные настройки
./scripts/service-manager.sh monitor 10 600  # обновление 10 сек, таймаут 10 мин

Пример вывода:
text

🚀 ===========================================
   ПРОДВИНУТЫЙ МЕНЕДЖЕР СЕРВИСОВ v2.0
   Tue Oct 28 22:30:45 PM EET 2025
   Автор: g1if
===========================================

📊 Мониторинг сервисов (обновление каждые 5 сек)
⏰ Таймаут: 300 сек | Для выхода нажмите Ctrl+C

🛠️ МОНИТОРИНГ СЕРВИСОВ - Цикл #15 (22:30:45)
Прошло: 75 сек | Осталось: 225 сек

🔧 Общее состояние системы:
  ● nginx.service - A high performance web server and a reverse proxy server

🚨 Критические сервисы:
  ✅ ssh: active
  ✅ nginx: active
  ✅ mysql: active
  🔵 docker: not-found
  ✅ apache2: active

📈 Статистика:
  Всего критических сервисов: 5
  Проблемных сервисов: 0
  Следующее обновление через: 5 сек

Авто-восстановление сервисов

Система автоматически обнаруживает и восстанавливает сбоящие сервисы:
bash

# Ручное восстановление
./scripts/service-manager.sh recover nginx

# Автоматическое в режиме мониторинга
./scripts/service-manager.sh monitor

Процесс восстановления:

    ✅ Обнаружение сбоя

    🔄 Многократные попытки перезапуска

    📋 Диагностика через анализ логов

    📢 Оповещение о результате

Расширенная диагностика
Анализ логов
bash

./scripts/service-manager.sh logs mysql 100

Поиск в:

    journalctl (systemd)

    /var/log/ файлы

    Системные логи

Валидация сервисов
bash

./scripts/service-manager.sh validate nginx

Проверяет:

    Существование сервиса

    Статус и настройки

    Доступность управления

Генерация отчетов
bash

# Автоматическая (при каждом запуске)
./scripts/service-manager.sh

# Ручная генерация
./scripts/service-manager.sh report

Содержание отчета:

    Статус критических сервисов

    Список неудачных сервисов

    Статистика системы

    Временные метки

Примеры использования
Экстренное восстановление веб-сервера
bash

./scripts/service-manager.sh recover nginx
./scripts/service-manager.sh logs nginx 20
./scripts/service-manager.sh status nginx

Мониторинг критической инфраструктуры
bash

# Длительный мониторинг с авто-восстановлением
./scripts/service-manager.sh monitor 5 3600

Аудит системы
bash

./scripts/service-manager.sh
./scripts/service-manager.sh report
./scripts/service-manager.sh list

Логи и файлы

    Основные логи: logs/service-manager.log

    Отчеты: reports/service-report-YYYYMMDD_HHMMSS.txt

    Конфигурация: configs/service-manager.conf

Зависимости
Обязательные

    systemctl / service / rc-status

    journalctl (для systemd)

    sudo (для управления сервисами)

Рекомендуемые

    mail - для email оповещений

    curl - для telegram оповещений

Автор

g1if

Примечание: Система автоматически адаптируется к доступному менеджеру сервисов и предоставляет максимально возможный функционал для каждой платформы. Все операции логируются для последующего анализа.
text


## 🚀 **ОСНОВНЫЕ УЛУЧШЕНИЯ В ВЕРСИИ 2.0**

1. ✅ **Мульти-системная поддержка** - systemd, sysvinit, OpenRC
2. ✅ **Расширенный мониторинг** - цветная индикация, таймауты, статистика
3. ✅ **Авто-восстановление** - интеллектуальные попытки перезапуска
4. ✅ **Умные оповещения** - интеграция с системой оповещений
5. ✅ **Генерация отчетов** - автоматические и ручные отчеты
6. ✅ **Валидация сервисов** - проверка и предложение альтернатив
7. ✅ **Расширенная диагностика** - детальный анализ логов
8. ✅ **Конфигурация** - гибкие настройки через конфиг файл
