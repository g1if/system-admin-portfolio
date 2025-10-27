#!/bin/bash
# 📊 Анализатор системных логов с интеллектуальным поиском
# Автор: g1if

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORT_DIR="$PROJECT_ROOT/reports"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Конфигурация
LOG_FILES=(
    "/var/log/syslog"
    "/var/log/auth.log" 
    "/var/log/kern.log"
    "/var/log/dpkg.log"
)

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "📊 ==========================================="
    echo "   АНАЛИЗАТОР СИСТЕМНЫХ ЛОГОВ v1.1"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📁 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  errors     - Поиск ошибок в логах"
    echo "  security   - Поиск событий безопасности"
    echo "  stats      - Статистика логов"
    echo "  monitor    - Мониторинг в реальном времени"
    echo "  report     - Полный отчет"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 errors"
    echo "  $0 security"
    echo "  $0 monitor"
}

# Проверка доступности логов
check_log_access() {
    local accessible_logs=()
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            accessible_logs+=("$log_file")
            print_success "Доступен: $log_file"
        elif [ -f "$log_file" ] && [ ! -r "$log_file" ]; then
            print_warning "Нет прав на чтение: $log_file"
        else
            print_error "Файл не найден: $log_file"
        fi
    done
    
    if [ ${#accessible_logs[@]} -eq 0 ]; then
        print_error "Нет доступных логов для анализа"
        echo ""
        echo "💡 Решение: Запустите скрипт с sudo или проверьте права доступа"
        return 1
    fi
    
    return 0
}

analyze_errors() {
    print_section "ПОИСК ОШИБОК В ЛОГАХ"
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            echo -e "\n${PURPLE}📋 Анализ: $(basename "$log_file")${NC}"
            
            # Разные уровни ошибок
	critical_count=$(sudo grep -i "error\|fail\|critical" "$log_file" 2>/dev/null | wc -l || echo "0")
	warning_count=$(sudo grep -i "warning" "$log_file" 2>/dev/null | wc -l || echo "0")

            if [ "$critical_count" -gt 0 ]; then
                print_error "Критические ошибки: $critical_count"
            else
                print_success "Критических ошибок: 0"
            fi
            
            if [ "$warning_count" -gt 0 ]; then
                print_warning "Предупреждения: $warning_count"
            else
                print_success "Предупреждений: 0"
            fi
            
            # Последние 3 ошибки
            if [ "$critical_count" -gt 0 ]; then
                echo "  🔍 Последние ошибки:"
                sudo grep -i "error\|fail\|critical" "$log_file" 2>/dev/null | tail -3 | while read line; do
                    echo "    📍 $(echo "$line" | cut -d' ' -f1-3) ..."
                done
            fi
        fi
    done
}

analyze_security() {
    print_section "СОБЫТИЯ БЕЗОПАСНОСТИ"
    
    if [ -r "/var/log/auth.log" ]; then
        # Статистика аутентификации
        failed_logins=$(sudo grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
        successful_logins=$(sudo grep -c "Accepted password" /var/log/auth.log 2>/dev/null || echo "0")
        invalid_users=$(sudo grep -c "Invalid user" /var/log/auth.log 2>/dev/null || echo "0")
        
        echo "  🔐 Статистика аутентификации:"
        echo "    🚫 Неудачных входов: $failed_logins"
        echo "    ✅ Успешных входов: $successful_logins"
        echo "    👤 Невалидных пользователей: $invalid_users"
        
        # Последние подозрительные события
        if [ "$failed_logins" -gt 0 ] || [ "$invalid_users" -gt 0 ]; then
            echo ""
            echo "  🔍 Последние подозрительные события:"
            sudo grep -i "failed\|invalid\|authentication failure" /var/log/auth.log 2>/dev/null | tail -3 | while read line; do
                echo "    ⚠️  $(echo "$line" | cut -d' ' -f1-3 | tail -c 50)..."
            done
        fi
    else
        print_warning "Лог аутентификации недоступен"
    fi
}

generate_stats() {
    print_section "СТАТИСТИКА ЛОГОВ"
    
    local total_size=0
    local total_lines=0
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            size=$(sudo du -b "$log_file" 2>/dev/null | cut -f1 || echo "0")
            lines=$(sudo wc -l "$log_file" 2>/dev/null | awk '{print $1}' || echo "0")
            modified=$(sudo stat -c %y "$log_file" 2>/dev/null | cut -d' ' -f1 || echo "неизвестно")
            
            total_size=$((total_size + size))
            total_lines=$((total_lines + lines))
            
            echo "  📊 $(basename "$log_file"):"
            echo "    📏 Размер: $(numfmt --to=iec $size)"
            echo "    📄 Строк: $lines"
            echo "    📅 Изменен: $modified"
        fi
    done
    
    echo ""
    echo "  📈 Общая статистика:"
    echo "    💾 Всего данных: $(numfmt --to=iec $total_size)"
    echo "    📖 Всего строк: $total_lines"
    echo "    📂 Файлов: ${#LOG_FILES[@]}"
}

real_time_monitor() {
    print_section "МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Отслеживаемые файлы:"
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            echo "    👁️  $(basename "$log_file")"
        fi
    done
    echo ""
    
    # Используем multitail если установлен, иначе обычный tail
    if command -v multitail >/dev/null 2>&1; then
        echo "  🚀 Используем multitail для красивого вывода..."
        sudo multitail -M 0 /var/log/syslog -I /var/log/auth.log
    else
        echo "  ℹ️  multitail не установлен, используем обычный tail"
        echo "  💡 Установите: sudo apt install multitail"
        echo ""
        
        # Простой мониторинг с цветами
        sudo tail -f /var/log/syslog /var/log/auth.log 2>/dev/null | while read line; do
            if echo "$line" | grep -q -i "error\|fail"; then
                echo -e "${RED}❌ $line${NC}"
            elif echo "$line" | grep -q -i "warning"; then
                echo -e "${YELLOW}⚠️  $line${NC}"
            elif echo "$line" | grep -q -i "accepted\|success"; then
                echo -e "${GREEN}✅ $line${NC}"
            else
                echo "  📝 $line"
            fi
        done
    fi
}

generate_report() {
    print_header
    echo "📅 Отчет создан: $(date)"
    echo "💻 Система: $(uname -a)"
    echo ""
    
    analyze_errors
    echo ""
    analyze_security  
    echo ""
    generate_stats
}

main() {
    case "${1:-}" in
        "errors")
            print_header
            analyze_errors
            ;;
        "security")
            print_header
            analyze_security
            ;;
        "stats")
            print_header
            generate_stats
            ;;
        "monitor")
            print_header
            real_time_monitor
            ;;
        "report")
            generate_report
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

# Проверяем доступность логов при запуске
if ! check_log_access; then
    echo ""
    echo "💡 Совет: Запустите с sudo для полного доступа:"
    echo "  sudo ./scripts/log-analyzer.sh [команда]"
    echo ""
fi

main "$@"
