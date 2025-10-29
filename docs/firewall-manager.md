# Firewall Manager v2.0

Расширенный менеджер фаервола с поддержкой UFW, iptables и firewalld. Предоставляет унифицированный интерфейс для управления сетевой безопасностью.

## Особенности

- 🔥 **Мульти-фаервол поддержка** - работа с UFW, iptables, firewalld
- 💾 **Автоматические бэкапы** - резервное копирование перед изменениями
- 🔄 **Восстановление** - восстановление правил из бэкапов
- 📊 **Детальный мониторинг** - статистика пакетов и трафика
- 🛡️ **Анализ безопасности** - проверка конфигурации на уязвимости
- ⚡ **Быстрая настройка** - автоматическая настройка common портов
- 🔍 **Инспекция портов** - просмотр открытых портов системы
- 📈 **Мониторинг в реальном времени** - отслеживание сетевой активности

## Использование

```bash
# Детальный статус фаервола
./scripts/firewall-manager.sh status

# Детальный список правил
./scripts/firewall-manager.sh list

# Разрешить порт
./scripts/firewall-manager.sh allow 22

# Разрешить порт с указанием протокола
./scripts/firewall-manager.sh allow 80 tcp

# Разрешить порт для конкретной подсети
./scripts/firewall-manager.sh allow 443 tcp 192.168.1.0/24

# Разрешить сервис
./scripts/firewall-manager.sh allow-service ssh

# Быстрая настройка common портов
./scripts/firewall-manager.sh setup-common

# Мониторинг трафика
./scripts/firewall-manager.sh monitor

# Анализ безопасности
./scripts/firewall-manager.sh security

Поддерживаемые фаерволы
🛡️ UFW (Uncomplicated Firewall)

    Системы: Ubuntu, Debian

    Особенности: Простой в использовании, рекомендуется для начинающих

    Команды: Полная поддержка всех операций

🔧 iptables

    Системы: Все Linux дистрибутивы

    Особенности: Мощный и гибкий, требует опыта

    Команды: Базовые операции, мониторинг

🌐 firewalld

    Системы: CentOS, RHEL, Fedora

    Особенности: Зональная архитектура, динамическое управление

    Команды: Управление сервисами и портами

Команды
Управление портами
allow <port> [protocol] [source] - Разрешить порт

Разрешает входящие подключения к указанному порту.

Параметры:

    port - номер порта или диапазон (80, 1000-2000)

    protocol - протокол (tcp, udp, по умолчанию tcp)

    source - исходный IP или подсеть (опционально)

Примеры:
bash

# Разрешить SSH
./scripts/firewall-manager.sh allow 22

# Разрешить HTTP и HTTPS
./scripts/firewall-manager.sh allow 80 tcp
./scripts/firewall-manager.sh allow 443 tcp

# Разрешить доступ только с локальной сети
./scripts/firewall-manager.sh allow 22 tcp 192.168.1.0/24

deny <port> [protocol] [source] - Запретить порт

Запрещает входящие подключения к указанному порту.
delete <port> [protocol] - Удалить правило

Удаляет правило для указанного порта.
Управление сервисами
allow-service <service> - Разрешить сервис

Разрешает входящие подключения для указанного сервиса.

Поддерживаемые сервисы:

    ssh, http, https, ftp, smtp, dns и другие

Пример:
bash

./scripts/firewall-manager.sh allow-service ssh
./scripts/firewall-manager.sh allow-service http

deny-service <service> - Запретить сервис

Запрещает входящие подключения для указанного сервиса.
Мониторинг и анализ
status - Детальный статус

Показывает подробную информацию о состоянии фаервола.

Пример вывода:
text

📊 ДЕТАЛЬНЫЙ СТАТУС ФАЕРВОЛА
  🔧 Обнаружен фаервол: ufw

📊 Статус UFW:
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

📋 Нумерованные правила:
[ 1] 22/tcp    ALLOW IN    Anywhere
[ 2] 80/tcp    ALLOW IN    Anywhere
[ 3] 443/tcp   ALLOW IN    Anywhere

📈 Статистика:
  🔻 Отброшено пакетов: 1245
  ✅ Принято пакетов: 89234

list - Детальный список правил

Отображает все правила фаервола с детализацией.
ports - Открытые порты системы

Показывает слушающие порты и активные подключения.
security - Анализ безопасности

Проверяет конфигурацию на соответствие лучшим практикам безопасности.
monitor - Мониторинг трафика

Режим реального времени для отслеживания сетевой активности.
Управление состоянием
enable - Включить фаервол

Активирует фаервол и применяет правила.
disable - Выключить фаервол

Отключает фаервол (временное отключение).
reset - Сбросить правила

Сбрасывает все правила к состоянию по умолчанию с созданием бэкапа.
Бэкапы и восстановление
backup - Создать бэкап

Создает резервную копию текущих правил.
restore [file] - Восстановить из бэкапа

Восстанавливает правила из ранее созданного бэкапа.
Утилиты
setup-common - Быстрая настройка

Автоматически настраивает common порты из конфигурации.
config - Создать конфигурацию

Создает файл конфигурации с настраиваемыми параметрами.
Конфигурация

Создайте конфигурационный файл:
bash

./scripts/firewall-manager.sh config

Редактируйте configs/firewall.conf:
bash

# Автоматическое определение фаервола
AUTO_DETECT_FIREWALL=true

# Предпочтительный фаервол
PREFERRED_FIREWALL="ufw"

# Настройки бэкапа
BACKUP_BEFORE_CHANGES=true
BACKUP_RETENTION_DAYS=7

# Стандартные порты для быстрого доступа
COMMON_PORTS=("22" "80" "443" "53" "21" "25" "110" "143" "993" "995")

# Зоны для firewalld
FIREWALLD_ZONES=("public" "internal" "trusted")

# Настройки логирования
LOG_DROPPED_PACKETS=true
LOG_LEVEL="low"

# Автоматические правила
AUTO_ALLOW_LOOPBACK=true
AUTO_ALLOW_SSH=true
AUTO_ALLOW_ICMP=true

# Политики по умолчанию
DEFAULT_INPUT_POLICY="DENY"
DEFAULT_OUTPUT_POLICY="ALLOW"
DEFAULT_FORWARD_POLICY="DENY"

Примеры использования
Базовая настройка сервера
bash

# Включить фаервол
./scripts/firewall-manager.sh enable

# Разрешить SSH
./scripts/firewall-manager.sh allow 22

# Разрешить веб-сервисы
./scripts/firewall-manager.sh allow 80
./scripts/firewall-manager.sh allow 443

# Проверить статус
./scripts/firewall-manager.sh status

Настройка для веб-сервера
bash

# Быстрая настройка common портов
./scripts/firewall-manager.sh setup-common

# Дополнительные порты для приложения
./scripts/firewall-manager.sh allow 3000
./scripts/firewall-manager.sh allow 5432 tcp 10.0.0.0/8

# Проверить безопасность
./scripts/firewall-manager.sh security

Мониторинг и обслуживание
bash

# Мониторинг трафика в реальном времени
./scripts/firewall-manager.sh monitor

# Создать бэкап перед изменениями
./scripts/firewall-manager.sh backup

# Восстановить после ошибки
./scripts/firewall-manager.sh restore

Расширенное управление
bash

# Разрешить диапазон портов (только iptables)
./scripts/firewall-manager.sh allow 8000-8100 tcp

# Разрешить сервис по имени
./scripts/firewall-manager.sh allow-service mysql

# Запретить доступ с конкретного IP
./scripts/firewall-manager.sh deny 22 tcp 192.168.1.100

Файлы и директории
Бэкапы

    Директория: backups/

    Формат: firewall-backup-YYYYMMDD_HHMMSS.rules

    Содержимое: Правила в родном формате фаервола

Логи

    Файл: logs/firewall-manager.log

    Формат: [timestamp] [level] [action] message

Конфигурация

    Файл: configs/firewall.conf

Best Practices
Рекомендуемая конфигурация

    Политика по умолчанию: DENY для входящих, ALLOW для исходящих

    Минимальные привилегии: Открывать только необходимые порты

    Логирование: Включить логирование отброшенных пакетов

    Регулярные бэкапы: Создавать бэкапы перед изменениями

    Мониторинг: Регулярно проверять статистику и логи

Порядок настройки
bash

# 1. Создать конфигурацию
./scripts/firewall-manager.sh config

# 2. Включить фаервол
./scripts/firewall-manager.sh enable

# 3. Настроить базовые правила
./scripts/firewall-manager.sh setup-common

# 4. Добавить специфичные правила
./scripts/firewall-manager.sh allow 3000
./scripts/firewall-manager.sh allow-service postgresql

# 5. Проверить безопасность
./scripts/firewall-manager.sh security

# 6. Создать бэкап
./scripts/firewall-manager.sh backup

Автоматизация
Cron задачи для регулярных операций
bash

# Ежедневный бэкап в 2:00
0 2 * * * /path/to/system-admin/scripts/firewall-manager.sh backup

# Еженедельная проверка безопасности в воскресенье в 3:00
0 3 * * 0 /path/to/system-admin/scripts/firewall-manager.sh security

Системные хуки

Добавьте в системные скрипты для автоматического бэкапа:
bash

#!/bin/bash
# /etc/network/if-pre-up.d/firewall-backup

/path/to/system-admin/scripts/firewall-manager.sh backup

Совместимость

    ✅ Дистрибутивы: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch Linux

    ✅ Фаерволы: UFW, iptables, firewalld

    ✅ Архитектуры: x86_64, ARM, ARM64

    ✅ Версии ядра: 4.4+, 5.4+, 6.0+

Безопасность

    🔒 Автобэкапы - перед каждым изменением создается резервная копия

    🚫 Валидация входных данных - проверка портов и IP адресов

    📝 Подробное логирование - аудит всех операций

    🛡️ Проверка безопасности - анализ конфигурации на уязвимости

Диагностика проблем
Фаервол не работает
bash

# Проверить статус
./scripts/firewall-manager.sh status

# Проверить открытые порты
./scripts/firewall-manager.sh ports

# Проверить логи
tail -f logs/firewall-manager.log

Проблемы с подключением
bash

# Мониторинг трафика для диагностики
./scripts/firewall-manager.sh monitor

# Проверить правила
./scripts/firewall-manager.sh list

# Временно отключить для тестирования
./scripts/firewall-manager.sh disable
# ... тестирование ...
./scripts/firewall-manager.sh enable

Восстановление после ошибки
bash

# Восстановить из последнего бэкапа
./scripts/firewall-manager.sh restore

# Или сбросить к defaults
./scripts/firewall-manager.sh reset

Автор

g1if

Примечание: Все изменения фаервола безопасны благодаря автоматическому созданию бэкапов. Система предоставляет унифицированный интерфейс для разных фаерволов и инструменты для мониторинга и анализа безопасности.
text


## 🚀 **ОСНОВНЫЕ УЛУЧШЕНИЯ В ВЕРСИИ 2.0**

1. ✅ **Мульти-фаервол поддержка** - UFW, iptables, firewalld
2. ✅ **Автоматические бэкапы** - резервное копирование перед изменениями
3. ✅ **Восстановление** - интерактивное восстановление из бэкапов
4. ✅ **Расширенное управление портами** - диапазоны, протоколы, источники
5. ✅ **Управление сервисами** - работа с предопределенными сервисами
6. ✅ **Детальный мониторинг** - статистика пакетов в реальном времени
7. ✅ **Анализ безопасности** - проверка конфигурации на уязвимости
8. ✅ **Быстрая настройка** - автоматическая настройка common портов
