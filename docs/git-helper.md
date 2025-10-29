# Git Helper v2.0

Продвинутый помощник для управления Git репозиториями с расширенными функциями и умными проверками.

## Особенности

- 🔧 **Упрощенные команды** - интуитивные алиасы для частых операций
- 🛡️ **Умные проверки** - автоматические проверки перед выполнением операций
- 📊 **Детальная информация** - статус, статистика, синхронизация
- 🌿 **Управление ветками** - создание, переключение, удаление, слияние
- 🔄 **Синхронизация** - автоматическая синхронизация с удаленным репозиторием
- 📝 **Conventional Commits** - поддержка стандартных типов коммитов
- 🚀 **Быстрые операции** - оптимизированные workflows для разработки
- 📈 **Статистика** - информация о репозитории, коммитах, размере
- 🛠️ **Настройка** - удобная настройка пользователя и удаленных репозиториев

## Использование

```bash
# Статус репозитория
./scripts/git-helper.sh status

# Умный коммит
./scripts/git-helper.sh commit "Описание изменений" feat

# Отправка изменений
./scripts/git-helper.sh push main

# Полная синхронизация
./scripts/git-helper.sh sync

# Управление ветками
./scripts/git-helper.sh branch create new-feature

# История коммитов
./scripts/git-helper.sh log 15

# Настройка Git
./scripts/git-helper.sh setup "Имя" "email@example.com" "https://github.com/user/repo.git"

Основные команды
📊 Статус и информация
bash

# Детальный статус репозитория
./scripts/git-helper.sh status

# Информация о репозитории
./scripts/git-helper.sh info

# История коммитов
./scripts/git-helper.sh log 10

Вывод status:
text

🔧 ===========================================
   ПРОДВИНУТЫЙ GIT ПОМОЩНИК v2.0
   Tue Oct 28 23:45:30 PM EET 2025
   Автор: g1if
===========================================

ℹ️ Статус репозитория
  📁 Репозиторий: system-admin-portfolio
  🌿 Ветка: main
  🌐 Удаленный: https://github.com/g1if/system-admin-portfolio.git

On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  modified:   scripts/git-helper.sh

📊 Синхронизация с удаленным репозиторием:
  📤 Впереди на 0 коммитов
  📥 Позади на 0 коммитов

💾 Коммиты
bash

# Простой коммит
./scripts/git-helper.sh commit "Исправление бага"

# Коммит с типом
./scripts/git-helper.sh commit "Добавлена новая функция" feat

# Коммит с другим типом
./scripts/git-helper.sh commit "Обновление документации" docs

Поддерживаемые типы коммитов:

    feat - новая функциональность

    fix - исправление бага

    docs - изменения в документации

    style - форматирование, отсутствие изменений в коде

    refactor - рефакторинг кода

    test - добавление или исправление тестов

    chore - обновление зависимостей, настройки

📤 Отправка и получение изменений
bash

# Отправка в текущую ветку
./scripts/git-helper.sh push

# Отправка в указанную ветку
./scripts/git-helper.sh push develop

# Принудительная отправка (осторожно!)
./scripts/git-helper.sh push main force

# Получение изменений
./scripts/git-helper.sh pull

# Полная синхронизация (pull + push)
./scripts/git-helper.sh sync

🌿 Управление ветками
bash

# Список веток
./scripts/git-helper.sh branch

# Создание новой ветки
./scripts/git-helper.sh branch create new-feature

# Удаление ветки
./scripts/git-helper.sh branch delete old-feature

# Слияние веток
./scripts/git-helper.sh merge develop

🔧 Утилиты
bash

# Просмотр различий
./scripts/git-helper.sh diff

# Просмотр различий в конкретном файле
./scripts/git-helper.sh diff script.sh

# Отмена изменений
./scripts/git-helper.sh undo        # Отмена неиндексированных изменений
./scripts/git-helper.sh undo add    # Отмена индексации
./scripts/git-helper.sh undo commit # Отмена коммита (сохраняя изменения)
./scripts/git-helper.sh undo hard   # Полная отмена всех изменений

# Инициализация нового репозитория
./scripts/git-helper.sh init my-project

# Настройка Git
./scripts/git-helper.sh setup

Workflow примеры
🚀 Стандартный workflow
bash

# 1. Проверить статус
./scripts/git-helper.sh status

# 2. Создать коммит
./scripts/git-helper.sh commit "Добавлен новый скрипт мониторинга" feat

# 3. Отправить изменения
./scripts/git-helper.sh push

# 4. Проверить результат
./scripts/git-helper.sh log 5

🌿 Workflow с ветками
bash

# 1. Создать feature ветку
./scripts/git-helper.sh branch create user-authentication

# 2. Работать над изменениями...
# 3. Сделать коммиты
./scripts/git-helper.sh commit "Добавлена базовая аутентификация" feat
./scripts/git-helper.sh commit "Исправлена валидация пароля" fix

# 4. Переключиться на main
git checkout main

# 5. Получить последние изменения
./scripts/git-helper.sh pull

# 6. Слить feature ветку
./scripts/git-helper.sh merge user-authentication

# 7. Отправить изменения
./scripts/git-helper.sh push

# 8. Удалить feature ветку
./scripts/git-helper.sh branch delete user-authentication

🔄 Workflow синхронизации
bash

# Быстрая синхронизация при начале работы
./scripts/git-helper.sh sync

# После завершения работы
./scripts/git-helper.sh commit "Завершение работы над функцией" feat
./scripts/git-helper.sh sync

Настройка Git
Первоначальная настройка
bash

# Базовая настройка
./scripts/git-helper.sh setup "Ваше Имя" "your.email@example.com"

# Полная настройка с удаленным репозиторием
./scripts/git-helper.sh setup "Ваше Имя" "your.email@example.com" "https://github.com/username/repo.git"

Ручная настройка (альтернатива)
bash

# Настройка пользователя
git config user.name "Ваше Имя"
git config user.email "your.email@example.com"

# Настройка удаленного репозитория
git remote add origin https://github.com/username/repo.git

# Дополнительные настройки
git config push.default simple

Conventional Commits

Скрипт поддерживает Conventional Commits стандарт:
📝 Формат коммитов
text

<тип>[область]: <описание>

[тело]

[нижний колонтитул]

🏷️ Типы коммитов

    feat: Новая функциональность

    fix: Исправление ошибки

    docs: Изменения в документации

    style: Изменения, не влияющие на смысл кода (форматирование)

    refactor: Изменения кода без исправления ошибок или добавления функций

    test: Добавление или исправление тестов

    chore: Изменения в процессе сборки или вспомогательных инструментах

💡 Примеры
bash

# Новая функция
./scripts/git-helper.sh commit "Добавлен мониторинг сети" feat

# Исправление бага
./scripts/git-helper.sh commit "Исправлена утечка памяти" fix

# Обновление документации
./scripts/git-helper.sh commit "Обновлен README" docs

# Рефакторинг
./scripts/git-helper.sh commit "Оптимизация алгоритма сортировки" refactor

Безопасные операции
🛡️ Проверки перед выполнением

    ✅ Проверка Git - убедиться, что Git установлен

    ✅ Проверка репозитория - текущая директория является Git репо

    ✅ Проверка удаленного репо - перед push/pull операциями

    ✅ Подтверждение действий - для опасных операций (удаление, force push)

    ✅ Проверка конфликтов - перед слиянием веток

⚠️ Опасные операции с подтверждением
bash

# Удаление ветки (требует подтверждения)
./scripts/git-helper.sh branch delete old-branch

# Принудительная отправка (требует подтверждения)
./scripts/git-helper.sh push main force

# Полная отмена изменений (требует подтверждения)
./scripts/git-helper.sh undo hard

Интеграция с другими скриптами
Использование в CI/CD
bash

#!/bin/bash
# Пример использования в скрипте развертывания

# Проверить, есть ли изменения для коммита
if ./scripts/git-helper.sh status | grep -q "Changes not staged for commit"; then
    ./scripts/git-helper.sh commit "Автоматический коммит от CI" chore
    ./scripts/git-helper.sh push
fi

Автоматизация workflow
bash

#!/bin/bash
# Скрипт для автоматического обновления документации

# Обновить документацию
./scripts/generate-docs.sh

# Закоммитить и отправить изменения
./scripts/git-helper.sh commit "Обновление документации" docs
./scripts/git-helper.sh push

Логи и диагностика
📝 Логи операций

    Файл логов: logs/git-helper.log

    Содержание: Все операции с временными метками

    Диагностика: Подробные сообщения об ошибках

🔍 Пример логов
text

[2025-10-28 23:45:30] [INFO] Статус репозитория
[2025-10-28 23:45:35] [COMMIT] feat: Добавлен новый скрипт мониторинга
[2025-10-28 23:45:40] [PUSH] Успешный push в main
[2025-10-28 23:45:45] [SYNC] Полная синхронизация репозитория

Советы и лучшие практики
💡 Рекомендации по использованию

    Всегда проверяйте статус перед коммитом

    Используйте meaningful сообщения коммитов

    Часто синхронизируйтесь с удаленным репозиторием

    Создавайте feature ветки для новой функциональности

    Удаляйте merged ветки для чистоты репозитория

🚀 Производительность

    Используйте sync для быстрой синхронизации

    Применяйте log с ограничением количества коммитов

    Используйте status для быстрой проверки состояния

🔧 Отладка проблем
bash

# Проверить логи операций
tail -f logs/git-helper.log

# Проверить настройки Git
git config --list

# Проверить подключение к удаленному репо
git remote -v

Автор

g1if

Примечание: Этот скрипт предназначен для упрощения повседневных операций с Git. Все опасные операции требуют подтверждения, а все действия подробно логируются для обеспечения прозрачности и возможности отладки.
text


## 🚀 **ОСНОВНЫЕ УЛУЧШЕНИЯ В ВЕРСИИ 2.0**

1. ✅ **Расширенный набор команд** - статус, коммит, пуш, пул, синхронизация, управление ветками
2. ✅ **Умные проверки** - автоматические проверки перед выполнением операций
3. ✅ **Conventional Commits** - поддержка стандартных типов коммитов
4. ✅ **Безопасные операции** - подтверждение для опасных действий
5. ✅ **Детальная информация** - статус репозитория, статистика, синхронизация
6. ✅ **Управление ветками** - создание, удаление, слияние, переключение
7. ✅ **Полная синхронизация** - автоматический pull + push workflow
8. ✅ **Подробное логирование** - все операции записываются в лог
