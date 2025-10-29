# Backup Manager v2.0

Умная система резервного копирования с автоопределением параметров, поддержкой множественных источников и расширенными функциями управления.

## Особенности

- 💾 **Автоопределение сжатия** - автоматически выбирает лучший доступный метод
- 📁 **Множественные источники** - поддержка нескольких директорий для бэкапа
- 🚫 **Гибкие исключения** - настраиваемые шаблоны исключения файлов
- 📦 **Бэкап пакетов** - автоматическое сохранение списков установленных пакетов
- 🧹 **Умная очистка** - автоматическое удаление старых бэкапов и логов
- 📊 **Детальная статистика** - подробная информация о размерах и датах
- 🔄 **Восстановление** - легкое восстановление файлов и пакетов
- 💰 **Контроль места** - проверка свободного места перед созданием бэкапа
- 🎯 **Поддержка дистрибутивов** - работа с dpkg, rpm, pacman пакетами

## Использование

```bash
# Создать новый бэкап
./scripts/backup-manager.sh create

# Очистить старые бэкапы
./scripts/backup-manager.sh clean

# Показать статистику
./scripts/backup-manager.sh stats

# Восстановить из бэкапа
./scripts/backup-manager.sh restore backups/backup_file.tar.gz ./restored

# Восстановить пакеты
./scripts/backup-manager.sh restore-packages backups/package-backups/packages_20231022.list

# Создать конфигурацию
./scripts/backup-manager.sh config

# Список бэкапов
./scripts/backup-manager.sh list

# Список бэкапов пакетов
./scripts/backup-manager.sh list-packages

Конфигурация

Создайте конфигурационный файл:
bash

./scripts/backup-manager.sh config

Редактируйте configs/backup.conf:
bash

# Директории для резервного копирования
BACKUP_SOURCES=("/etc" "$HOME/projects" "/var/www")

# Срок хранения бэкапов (в днях)
BACKUP_RETENTION_DAYS=7

# Метод сжатия (auto, gzip, bzip2, xz, pigz, none)
BACKUP_COMPRESSION="auto"

# Префикс для файлов бэкапов
BACKUP_PREFIX="system-backup"

# Исключения (шаблоны для исключения из бэкапа)
BACKUP_EXCLUDES=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*" "*.iso" "*.ova" "*.vmdk" "*.docker/*")

# Инкрементальные бэкапы
ENABLE_INCREMENTAL=false
INCREMENTAL_LEVEL=1

# Бэкап списка установленных пакетов
ENABLE_PACKAGE_BACKUP=true

# Методы уведомлений
NOTIFICATION_METHODS=("log" "console")

# Срок хранения логов (дни)
LOG_RETENTION_DAYS=30

Поддерживаемые системы пакетов
🐧 Debian/Ubuntu (dpkg)

    Экспорт: dpkg --get-selections

    Восстановление: dpkg --set-selections && apt-get dselect-upgrade

🔴 RedHat/CentOS (rpm)

    Экспорт: rpm -qa

    Восстановление: Ручное (требует переустановки системы)

🎯 Arch Linux (pacman)

    Экспорт: pacman -Qqe

    Восстановление: pacman -S --needed

⭕ Snap

    Экспорт: snap list

    Восстановление: Ручное

📦 Flatpak

    Экспорт: flatpak list

    Восстановление: Ручное

Методы сжатия
auto (Автоматический выбор)

    pigz - многопоточный gzip (самый быстрый)

    gzip - стандартное сжатие

    bzip2 - лучшее сжатие, медленнее

    xz - максимальное сжатие, очень медленно

    none - без сжатия

Ручной выбор

    gzip - баланс скорости и сжатия

    bzip2 - лучшее сжатие для текстовых файлов

    xz - максимальное сжатие

    pigz - многопоточная версия gzip

    none - без сжатия (быстрее всего)

Примеры использования
Создание полного бэкапа
bash

./scripts/backup-manager.sh create

Вывод:
text

💾 ===========================================
   МЕНЕДЖЕР РЕЗЕРВНОГО КОПИРОВАНИЯ v2.0
   Tue Oct 28 22:15:30 PM EET 2025
   Автор: g1if
===========================================

📊 ПРОВЕРКА ИСТОЧНИКОВ
  ✅ Доступен: /etc
  ✅ Доступен: /home/user/projects
  ✅ Доступен (требуется sudo): /var/www

📊 ОЦЕНКА РАЗМЕРА
  📐 Примерный размер бэкапа: 2.1 GB
  💾 Свободно места: 15.4 GB
  📦 Требуется: 2.5 GB

📦 БЭКАП СПИСКА ПАКЕТОВ
  🐧 Экспорт списка пакетов dpkg...
  ✅ Список пакетов dpkg сохранен: packages_20251028_221530.list

📊 СОЗДАНИЕ АРХИВА
  📦 Создание архива: system-backup_20251028_221530.tar
  🚫 Исключения: *.tmp *.log cache/* node_modules/* .git/* *.iso *.ova *.vmdk *.docker/*
  🔄 Выполнение: tar -cf ... (источников: 3)
  🔑 Используем sudo для доступа к системным файлам...
  ✅ Архив создан: 2.3 GB

📊 СЖАТИЕ
  🔄 Сжатие с pigz (многопоточное)...
  ✅ Сжатие pigz завершено
✅ Бэкап создан: system-backup_20251028_221530.tar.gz (1.1 GB)
  📈 Коэффициент сжатия: 2.09x

📋 ИНФОРМАЦИЯ О БЭКАПЕ:
  Файл: system-backup_20251028_221530.tar.gz
  Размер: 1.1 GB
  Дата: Tue Oct 28 22:15:30 PM EET 2025
  Источники: /etc /home/user/projects /var/www
  Сжатие: pigz
  Коэффициент сжатия: 2.09x
  Директория: /path/to/system-admin/backups

Восстановление системы
bash

# Восстановление файлов
./scripts/backup-manager.sh restore backups/system-backup_20251028_221530.tar.gz ./restored

# Восстановление пакетов
./scripts/backup-manager.sh restore-packages backups/package-backups/packages_20251028_221530.list

Мониторинг и обслуживание
bash

# Статистика бэкапов
./scripts/backup-manager.sh stats

# Очистка старых бэкапов
./scripts/backup-manager.sh clean

# Список доступных бэкапов
./scripts/backup-manager.sh list

Структура файлов
Директории

    Бэкапы: backups/

    Бэкапы пакетов: backups/package-backups/

    Логи: logs/backup-manager.log

    Конфигурация: configs/backup.conf

Форматы файлов

    Полные бэкапы: ${PREFIX}_${TIMESTAMP}.tar.{gz|bz2|xz}

    Бэкапы пакетов: packages_${TIMESTAMP}.{list|rpm|pacman|snap|flatpak}

Зависимости
Обязательные

    tar - создание архивов

Опциональные (для сжатия)

    gzip / pigz - сжатие gzip

    bzip2 - сжатие bzip2

    xz - сжатие xz

    bc / numfmt - форматирование размеров

Системные

    dpkg - пакеты Debian/Ubuntu

    rpm - пакеты RedHat/CentOS

    pacman - пакеты Arch Linux

    snap - snap пакеты

    flatpak - flatpak пакеты

Автоматизация
Cron для регулярных бэкапов
bash

# Ежедневный бэкап в 2:00
0 2 * * * /path/to/system-admin/scripts/backup-manager.sh create

# Еженедельная очистка в воскресенье в 3:00
0 3 * * 0 /path/to/system-admin/scripts/backup-manager.sh clean

Systemd служба (опционально)
ini

[Unit]
Description=Backup Manager
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/system-admin/scripts/backup-manager.sh create
User=root

[Install]
WantedBy=multi-user.target

Совместимость

    ✅ Дистрибутивы: Ubuntu, Debian, CentOS, RHEL, Arch Linux

    ✅ Файловые системы: ext4, xfs, btrfs, zfs

    ✅ Архитектуры: x86_64, ARM, ARM64

    ✅ Размеры: Поддержка больших файлов (>2GB)

Безопасность

    🔒 Проверка прав - автоматическое определение необходимости sudo

    📝 Подробное логирование - полная история операций

    🚫 Исключения по умолчанию - исключение временных файлов и кэшей

    💾 Проверка целостности - проверка размеров и дат

Автор

g1if

Примечание: Система автоматически адаптируется к доступным утилитам и предоставляет детальную диагностику при возникновении проблем. Все настройки могут быть изменены через конфигурационный файл.
text


## 🚀 **ОСНОВНЫЕ УЛУЧШЕНИЯ В ВЕРСИИ 2.0**

1. ✅ **Проверка зависимостей** - автоматическая валидация окружения
2. ✅ **Бэкап пакетов** - поддержка dpkg, rpm, pacman, snap, flatpak
3. ✅ **Контроль места** - проверка свободного места перед бэкапом
4. ✅ **Оценка размера** - предварительная оценка размера бэкапа
5. ✅ **Улучшенное логирование** - структурированные логи с уровнями
6. ✅ **Автоочистка логов** - удаление старых логов по расписанию
7. ✅ **Восстановление пакетов** - команда для восстановления пакетов
8. ✅ **Расширенная статистика** - детальная информация о бэкапах
