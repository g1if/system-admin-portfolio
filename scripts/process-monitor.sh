#!/bin/bash
# 🔄 Мониторинг процессов и ресурсов
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
    echo "🔄 ==========================================="
    echo "   МОНИТОРИНГ ПРОЦЕССОВ v1.0"
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
    echo "  top        - Топ процессов (похоже на htop)"
    echo "  find       - Поиск процесса"
    echo "  kill       - Завершить процесс"
    echo "  tree       - Дерево процессов"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 top"
    echo "  $0 find nginx"
    echo "  $0 kill 1234"
}

show_top() {
    print_header
    echo "📊 Топ процессов по использованию ресурсов:"
    echo ""
    
    # Показываем топ процессов по CPU
    echo "💻 Топ по CPU:"
    ps aux --sort=-%cpu | head -10
    
    echo ""
    echo "🧠 Топ по памяти:"
    ps aux --sort=-%mem | head -10
}

find_process() {
    local pattern=$1
    
    if [ -z "$pattern" ]; then
        echo "❌ Укажите шаблон для поиска"
        return 1
    fi
    
    echo "🔍 Поиск процессов с шаблоном: $pattern"
    ps aux | grep -i "$pattern" | grep -v grep
}

show_tree() {
    print_header
    echo "🌳 Дерево процессов:"
    
    if command -v pstree >/dev/null 2>&1; then
        pstree
    else
        echo "📦 Утилита pstree не установлена"
        echo "💡 Установите: sudo apt install psmisc"
        echo ""
        echo "📝 Альтернативный вывод:"
        ps -ejH | head -20
    fi
}

main() {
    case "${1:-}" in
        "top")
            show_top
            ;;
        "find")
            find_process "$2"
            ;;
        "kill")
            kill_process "$2"
            ;;
        "tree")
            show_tree
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
