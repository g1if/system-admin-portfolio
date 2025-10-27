# Package Manager v1.0

Менеджер пакетов и обновлений с автоопределением дистрибутива и резервным копированием.

## Особенности

- 📦 **Автоопределение дистрибутива** - apt, yum, dnf, pacman
- 🔄 **Управление обновлениями** - проверка и установка обновлений
- 💾 **Резервное копирование** - автоматический бэкап конфигов перед обновлением
- 🧹 **Очистка кэша** - освобождение места на диске
- 🔍 **Поиск пакетов** - поиск по репозиториям
- 📊 **Статистика** - информация об установленных пакетах
- 🛡️ **Безопасность** - подтверждение действий и логирование

## Поддерживаемые системы

- **Debian/Ubuntu** (apt)
- **CentOS/RHEL/Fedora** (yum/dnf)  
- **Arch Linux** (pacman)
- **Alpine Linux** (apk)

## Использование

```bash
# Полный анализ системы и обновлений
./scripts/package-manager.sh

# Управление обновлениями
./scripts/package-manager.sh update
./scripts/package-manager.sh update auto

# Управление пакетами
./scripts/package-manager.sh install nginx mysql
./scripts/package-manager.sh remove old-package
./scripts/package-manager.sh search python

# Поиск информации
./scripts/package-manager.sh info curl
./scripts/package-manager.sh list
./scripts/package-manager.sh list ssh

# Сервисные функции
./scripts/package-manager.sh clean
./scripts/package-manager.sh backup

Функционал
🔄 Управление обновлениями

    Проверка доступных обновлений

    Установка обновлений с подтверждением

    Автоматическое обновление (без подтверждения)

    Резервное копирование конфигов перед обновлением

📦 Управление пакетами

    Установка пакетов с зависимостями

    Удаление пакетов с очисткой

    Поиск пакетов в репозиториях

    Информация о конкретном пакете

💾 Резервное копирование

    Автоматический бэкап перед критическими операциями

    Копирование конфигурационных файлов

    Архивирование бэкапов

    Хранение истории бэкапов

🧹 Оптимизация

    Очистка кэша пакетов

    Удаление неиспользуемых зависимостей

    Освобождение места на диске

📊 Мониторинг

    Статистика установленных пакетов

    Отслеживание размера кэша

    Логирование всех операций

Безопасность

    Подтверждение деструктивных операций

    Резервное копирование перед изменениями

    Детальное логирование всех действий

    Проверка прав доступа

Структура файлов
text

system-admin/
├── scripts/
│   └── package-manager.sh
├── logs/
│   └── package-manager.log
├── backups/
│   └── package-backups/
│       └── package-backup-20231025-151023.tar.gz
└── cache/
    └── package-cache/

Примеры использования
Безопасное обновление системы
bash

./scripts/package-manager.sh update

Массовая установка пакетов
bash

./scripts/package-manager.sh install nginx mysql php postgresql

Поиск и установка разработочных инструментов
bash

./scripts/package-manager.sh search python3
./scripts/package-manager.sh install python3 python3-pip git

Очистка системы
bash

./scripts/package-manager.sh clean
./scripts/package-manager.sh remove old-package1 old-package2

Логи

    Основные логи: logs/package-manager.log

    Детальная информация о всех операциях

    История обновлений и установок

    Ошибки и предупреждения
