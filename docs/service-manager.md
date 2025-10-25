# Service Manager v1.0

Менеджер системных сервисов с автоопределением и мониторингом в реальном времени.

## Особенности

- 🚀 **Автоопределение менеджера** - systemd, sysvinit, openrc
- 📊 **Мониторинг в реальном времени** - отслеживание состояния сервисов
- 🔧 **Управление сервисами** - start, stop, restart, status
- 📋 **Просмотр логов** - анализ журналов сервисов
- 🛠️ **Автовосстановление** - автоматическое исправление сбоев
- ⚙️ **Конфигурация** - настройка мониторинга для каждого сервиса

## Использование

```bash
# Полный анализ сервисов
./scripts/service-manager.sh

# Мониторинг в реальном времени
./scripts/service-manager.sh monitor

# Управление конкретным сервисом
./scripts/service-manager.sh start nginx
./scripts/service-manager.sh stop apache2
./scripts/service-manager.sh restart ssh

# Просмотр логов
./scripts/service-manager.sh logs nginx 50

# Автовосстановление
./scripts/service-manager.sh recover mysql

# Список сервисов
./scripts/service-manager.sh list
./scripts/service-manager.sh list mysql

# Создание конфигурации
./scripts/service-manager.sh config nginx

Поддерживаемые системы

    systemd (Ubuntu 16.04+, Debian 8+, CentOS 7+)

    sysvinit (старые версии Debian/Ubuntu)

    openrc (Gentoo, Alpine Linux)

Функционал
🎯 Автоопределение

    Автоматическое определение менеджера сервисов

    Адаптация команд под конкретную систему

    Совместимость с разными дистрибутивами

📊 Мониторинг

    Отслеживание состояния сервисов в реальном времени

    Обнаружение неудачных сервисов

    Контроль критических сервисов (SSH, базы данных, веб-серверы)

🔧 Управление

    Запуск, остановка, перезапуск сервисов

    Просмотр подробного статуса

    Включение/отключение автозагрузки

📋 Анализ логов

    Просмотр журналов через journalctl

    Анализ файлов логов в /var/log

    Фильтрация по количеству строк

🛠️ Восстановление

    Автоматический перезапуск упавших сервисов

    Анализ причин сбоев

    Уведомления о проблемах

Конфигурация

Файлы конфигурации создаются в config/ и содержат:

    Интервал проверки сервиса

    Максимальное количество попыток перезапуска

    Действия при сбое и успехе

    Дополнительные параметры

Логи

    Логи: logs/service-manager.log

    Детальная информация о всех операциях

    История управления сервисами

Примеры использования
Мониторинг критических сервисов
bash

./scripts/service-manager.sh monitor

Восстановление веб-сервера
bash

./scripts/service-manager.sh recover nginx

Анализ логов базы данных
bash

./scripts/service-manager.sh logs mysql 100

Управление сетевыми сервисами
bash

./scripts/service-manager.sh restart networking
./scripts/service-manager.sh status ssh
