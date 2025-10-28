#!/bin/bash
# ⏰ Менеджер cron заданий
# Автор: g1if

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}"
    echo "⏰ ==========================================="
    echo "   МЕНЕДЖЕР CRON ЗАДАНИЙ v1.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  list       - Список заданий"
    echo "  add        - Добавить задание"
    echo "  remove     - Удалить задание"
    echo "  edit       - Редактировать задания"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 list"
    echo "  $0 add"
    echo "  $0 edit"
}

list_jobs() {
    print_header
    echo "📋 Текущие cron задания:"
    echo ""
    
    echo "👤 Задания текущего пользователя:"
    crontab -l 2>/dev/null || echo "  Нет заданий"
    
    echo ""
    echo "📁 Системные задания:"
    ls /etc/cron.*/* 2>/dev/null | head -10 || echo "  Недоступно"
}

add_job() {
    echo "➕ Добавление нового cron задания"
    echo "📝 Формат: * * * * * команда"
    echo "   минута час день месяц день_недели"
    echo ""
    read -p "Введите cron выражение: " cron_expr
    read -p "Введите команду: " command
    
    (crontab -l 2>/dev/null; echo "$cron_expr $command") | crontab -
    echo "✅ Задание добавлено"
}

remove_job() {
    echo "🗑️  Удаление cron задания"
    current_jobs=$(crontab -l 2>/dev/null)
    
    if [ -z "$current_jobs" ]; then
        echo "  Нет заданий для удаления"
        return 0
    fi
    
    echo "📋 Текущие задания:"
    echo "$current_jobs" | cat -n
    
    read -p "Введите номер задания для удаления: " job_num
    if [[ ! $job_num =~ ^[0-9]+$ ]]; then
        echo "❌ Некорректный номер задания"
        return 1
    fi
    
    new_jobs=$(echo "$current_jobs" | sed "${job_num}d")
    echo "$new_jobs" | crontab -
    echo "✅ Задание $job_num удалено"
}

# Открой файл и найди функцию main():
main() {
    case "${1:-}" in
        "list")
            list_jobs
            ;;
        "add")
            add_job
            ;;
        "remove")
            remove_job
            ;;
        "edit")
            crontab -e
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
