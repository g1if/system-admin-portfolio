#!/bin/bash
# 💾 Менеджер дисков и файловых систем
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/disk-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_header() {
    echo -e "${MAGENTA}"
    echo "💾 ==========================================="
    echo "   МЕНЕДЖЕР ДИСКОВ И ФАЙЛОВЫХ СИСТЕМ v1.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}💿 $1${NC}"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "  ${GREEN}✅ $message${NC}" ;;
        "WARN") echo -e "  ${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "  ${RED}❌ $message${NC}" ;;
        "INFO") echo -e "  ${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Получение информации о дисках
get_disk_info() {
    print_section "ИНФОРМАЦИЯ О ДИСКАХ"
    
    echo "  📊 Общее использование дисков:"
    df -h | grep -E '^/dev/' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local avail=$(echo "$line" | awk '{print $4}')
        local use_percent=$(echo "$line" | awk '{print $5}')
        local mount=$(echo "$line" | awk '{print $6}')
        
        # Цвет в зависимости от использования
        local percent_num=$(echo "$use_percent" | tr -d '%')
        if [ "$percent_num" -gt 90 ]; then
            echo -e "    ${RED}🚨 $device: $used/$size ($use_percent) на $mount${NC}"
        elif [ "$percent_num" -gt 80 ]; then
            echo -e "    ${YELLOW}⚠️  $device: $used/$size ($use_percent) на $mount${NC}"
        else
            echo -e "    ${GREEN}✅ $device: $used/$size ($use_percent) на $mount${NC}"
        fi
    done
    
    # Информация о блочных устройствах
    echo ""
    echo "  🔧 Блочные устройства:"
    if command -v lsblk >/dev/null 2>&1; then
        lsblk | head -10 | while read -r line; do
            echo "    📟 $line"
        done
    else
        echo "    ℹ️  Команда lsblk не найдена"
    fi
}

# Анализ inodes
check_inodes() {
    print_section "АНАЛИЗ INODES"
    
    echo "  🔍 Использование inodes:"
    df -i | grep -E '^/dev/' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local total_inodes=$(echo "$line" | awk '{print $2}')
        local used_inodes=$(echo "$line" | awk '{print $3}')
        local free_inodes=$(echo "$line" | awk '{print $4}')
        local use_percent=$(echo "$line" | awk '{print $5}')
        local mount=$(echo "$line" | awk '{print $6}')
        
        local percent_num=$(echo "$use_percent" | tr -d '%')
        if [ "$percent_num" -gt 90 ]; then
            echo -e "    ${RED}🚨 $device: $used_inodes/$total_inodes inodes ($use_percent) на $mount${NC}"
        elif [ "$percent_num" -gt 80 ]; then
            echo -e "    ${YELLOW}⚠️  $device: $used_inodes/$total_inodes inodes ($use_percent) на $mount${NC}"
        else
            echo -e "    ${GREEN}✅ $device: $used_inodes/$total_inodes inodes ($use_percent) на $mount${NC}"
        fi
    done
}

# Поиск больших файлов
find_large_files() {
    local top_count=${1:-10}
    
    print_section "ПОИСК БОЛЬШИХ ФАЙЛОВ (ТОП-$top_count)"
    
    echo "  🔎 Поиск самых больших файлов в системе..."
    
    # Поиск в корневой файловой системе
    local large_files=$(find / -type f -size +100M 2>/dev/null | xargs du -h 2>/dev/null | sort -rh | head -n "$top_count" 2>/dev/null || true)
    
    if [ -n "$large_files" ]; then
        echo "$large_files" | while read -r size file; do
            echo "    📁 $size - $file"
        done
    else
        echo "    ℹ️  Большие файлы не найдены или нет прав доступа"
    fi
    
    # Поиск в домашней директории
    echo ""
    echo "  🏠 Большие файлы в домашних директориях:"
    local home_files=$(find /home -type f -size +50M 2>/dev/null | xargs du -h 2>/dev/null | sort -rh | head -n 5 2>/dev/null || true)
    
    if [ -n "$home_files" ]; then
        echo "$home_files" | while read -r size file; do
            echo "    🏠 $size - $file"
        done
    else
        echo "    ℹ️  Большие файлы в /home не найдены"
    fi
}

# Анализ логов на предмет ошибок диска
check_disk_errors() {
    print_section "ПРОВЕРКА ОШИБОК ДИСКА"
    
    echo "  🔍 Поиск ошибок диска в логах..."
    
    # Проверка dmesg на ошибки диска
    local disk_errors=$(dmesg 2>/dev/null | grep -i "error.*disk\|disk.*error\|I/O error" | head -5 || true)
    
    if [ -n "$disk_errors" ]; then
        print_status "ERROR" "Обнаружены ошибки диска:"
        echo "$disk_errors" | while read -r error; do
            echo "    ❌ $error"
        done
    else
        print_status "OK" "Ошибки диска не обнаружены"
    fi
    
    # Проверка SMART статуса
    echo ""
    echo "  💡 Проверка SMART статуса дисков..."
    if command -v smartctl >/dev/null 2>&1; then
        for device in /dev/sd?; do
            if [ -b "$device" ]; then
                local smart_status=$(smartctl -H "$device" 2>/dev/null | grep "SMART overall-health" || true)
                if [ -n "$smart_status" ]; then
                    if echo "$smart_status" | grep -q "PASSED"; then
                        echo "    ✅ $device: SMART статус в норме"
                    else
                        echo -e "    ${RED}❌ $device: Проблемы со SMART${NC}"
                    fi
                fi
            fi
        done
    else
        echo "    ℹ️  smartctl не установлен"
        echo "    💡 Установите: sudo apt install smartmontools"
    fi
}

# Мониторинг в реальном времени
monitor_io() {
    print_section "МОНИТОРИНГ I/O В РЕАЛЬНОМ ВРЕМЕНИ"
    
    echo "  📈 Активность дисков (обновление каждые 2 секунды)..."
    echo -e "  ${CYAN}Для выхода нажмите Ctrl+C${NC}"
    
    if command -v iostat >/dev/null 2>&1; then
        iostat -dx 2
    elif command -v vmstat >/dev/null 2>&1; then
        vmstat 2
    else
        echo "    ℹ️  iostat/vmstat не установлены"
        echo "    💡 Установите: sudo apt install sysstat"
    fi
}

# Очистка временных файлов
clean_temp_files() {
    print_section "ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ"
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "$HOME/.cache"
        "/var/cache"
    )
    
    local total_freed=0
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "  🧹 Очистка $dir..."
            local size_before=$(du -s "$dir" 2>/dev/null | cut -f1 || echo 0)
            
            # Безопасная очистка
            find "$dir" -type f -atime +7 -delete 2>/dev/null || true
            
            local size_after=$(du -s "$dir" 2>/dev/null | cut -f1 || echo 0)
            local freed=$((size_before - size_after))
            total_freed=$((total_freed + freed))
            
            echo "    📊 Освобождено: ${freed}K"
        fi
    done
    
    if [ "$total_freed" -gt 0 ]; then
        print_status "OK" "Очистка завершена. Освобождено: ${total_freed}K"
    else
        print_status "INFO" "Нечего очищать"
    fi
}

# Анализ файловых систем
analyze_filesystems() {
    print_section "АНАЛИЗ ФАЙЛОВЫХ СИСТЕМ"
    
    echo "  📋 Типы файловых систем:"
    mount | grep -E '^/dev/' | awk '{print $5}' | sort | uniq -c | while read -r count fs_type; do
        echo "    💾 $fs_type: $count точек монтирования"
    done
    
    # Проверка на read-only файловые системы
    echo ""
    echo "  🔒 Проверка файловых систем на read-only:"
    local ro_systems=$(mount | grep "(ro," | wc -l)
    if [ "$ro_systems" -gt 0 ]; then
        print_status "WARN" "Найдено read-only файловых систем: $ro_systems"
        mount | grep "(ro," | while read -r line; do
            echo "    🔓 $line"
        done
    else
        print_status "OK" "Нет read-only файловых систем"
    fi
}

# Основная функция
main() {
    print_header
    log "Запуск менеджера дисков"
    
    get_disk_info
    check_inodes
    find_large_files 8
    check_disk_errors
    analyze_filesystems
    
    echo ""
    echo -e "${GREEN}✅ Анализ дисков завершен${NC}"
    log "Анализ дисков завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Функции для обработки команд
cmd_monitor() {
    print_header
    monitor_io
}

cmd_clean() {
    print_header
    clean_temp_files
}

cmd_large_files() {
    local count=${2:-15}
    print_header
    find_large_files "$count"
}

cmd_info() {
    print_header
    get_disk_info
    check_inodes
    analyze_filesystems
}

cmd_help() {
    echo -e "${CYAN}💾 Менеджер дисков и файловых систем - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  monitor          - мониторинг I/O в реальном времени"
    echo "  clean            - очистка временных файлов"
    echo "  large-files [N]  - поиск N самых больших файлов (по умолчанию 15)"
    echo "  info             - краткая информация о дисках"
    echo "  help             - эта справка"
    echo ""
    echo "Без аргументов: полный анализ дисков и файловых систем"
    echo ""
    echo "Примеры:"
    echo "  $0                      # Полный анализ"
    echo "  $0 monitor              # Мониторинг в реальном времени"
    echo "  $0 clean                # Очистка временных файлов"
    echo "  $0 large-files 20       # 20 самых больших файлов"
    echo "  $0 info                 # Краткая информация"
}

# Обработка аргументов
case "${1:-}" in
    "monitor") cmd_monitor ;;
    "clean") cmd_clean ;;
    "large-files") cmd_large_files "$@" ;;
    "info") cmd_info ;;
    "help") cmd_help ;;
    *) main ;;
esac
