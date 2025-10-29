#!/bin/bash
# 💾 Менеджер дисков и файловых систем с расширенным мониторингом
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
LOG_FILE="$LOG_DIR/disk-manager.log"
CONFIG_FILE="$CONFIG_DIR/disk-manager.conf"

# Создаем директории
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" 2>/dev/null || true

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;95m'
NC='\033[0m' # No Color

# Логирование
log() {
    local level=${2:-"INFO"}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_header() {
    echo -e "${MAGENTA}"
    echo "💾 ==========================================="
    echo "   МЕНЕДЖЕР ДИСКОВ И ФАЙЛОВЫХ СИСТЕМ v2.0"
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
        "CRITICAL") echo -e "  ${RED}🚨 $message${NC}" ;;
    esac
    log "$message" "$status"
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in df du find; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты
    if ! command -v lsblk &> /dev/null; then
        optional_missing+=("lsblk")
    fi
    
    if ! command -v smartctl &> /dev/null; then
        optional_missing+=("smartmontools")
    fi
    
    if ! command -v iostat &> /dev/null; then
        optional_missing+=("sysstat")
    fi
    
    if ! command -v ncdu &> /dev/null; then
        optional_missing+=("ncdu")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_status "ERROR" "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        print_status "WARN" "Отсутствуют опциональные утилиты: ${optional_missing[*]}"
        echo "💡 Для расширенного функционала установите: sudo apt install ${optional_missing[*]}"
    fi
    
    return 0
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_status "INFO" "Конфигурация загружена: $CONFIG_FILE"
    else
        # Конфигурация по умолчанию
        WARNING_THRESHOLD=80
        CRITICAL_THRESHOLD=90
        INODE_WARNING_THRESHOLD=80
        INODE_CRITICAL_THRESHOLD=90
        LARGE_FILE_THRESHOLD_MB=100
        HOME_LARGE_FILE_THRESHOLD_MB=50
        TEMP_FILE_AGE_DAYS=7
        LOG_FILE_AGE_DAYS=30
        ENABLE_SMART_MONITORING=true
        ENABLE_IO_MONITORING=true
        EXCLUDE_PATTERNS=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*")
        
        print_status "WARN" "Используется конфигурация по умолчанию"
    fi
}

# Создание конфигурационного файла
create_config() {
    cat > "$CONFIG_FILE" << 'CONFIG_EOF'
# Конфигурация менеджера дисков v2.0

# Пороговые значения использования диска (%)
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Пороговые значения использования inodes (%)
INODE_WARNING_THRESHOLD=80
INODE_CRITICAL_THRESHOLD=90

# Пороги для больших файлов (МБ)
LARGE_FILE_THRESHOLD_MB=100
HOME_LARGE_FILE_THRESHOLD_MB=50

# Возраст файлов для очистки (дни)
TEMP_FILE_AGE_DAYS=7
LOG_FILE_AGE_DAYS=30

# Включение мониторинга
ENABLE_SMART_MONITORING=true
ENABLE_IO_MONITORING=true

# Исключения при поиске файлов
EXCLUDE_PATTERNS=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*" "*.iso" "*.docker/*")
CONFIG_EOF
    
    print_status "OK" "Создан файл конфигурации: $CONFIG_FILE"
}

# Человеко-читаемый размер
human_size() {
    local bytes=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B "$bytes"
    elif command -v bc >/dev/null 2>&1; then
        if [ "$bytes" -gt 1099511627776 ]; then
            echo "$(echo "scale=2; $bytes/1099511627776" | bc) TB"
        elif [ "$bytes" -gt 1073741824 ]; then
            echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
        elif [ "$bytes" -gt 1048576 ]; then
            echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
        elif [ "$bytes" -gt 1024 ]; then
            echo "$(echo "scale=2; $bytes/1024" | bc) KB"
        else
            echo "$bytes bytes"
        fi
    else
        # Простой вывод
        if [ "$bytes" -gt 1099511627776 ]; then
            echo "$((bytes / 1099511627776)) TB"
        elif [ "$bytes" -gt 1073741824 ]; then
            echo "$((bytes / 1073741824)) GB"
        elif [ "$bytes" -gt 1048576 ]; then
            echo "$((bytes / 1048576)) MB"
        elif [ "$bytes" -gt 1024 ]; then
            echo "$((bytes / 1024)) KB"
        else
            echo "$bytes bytes"
        fi
    fi
}

# Получение информации о дисках
get_disk_info() {
    print_section "ИНФОРМАЦИЯ О ДИСКАХ"
    
    echo "  📊 Общее использование дисков:"
    local has_critical=0
    local has_warning=0
    
    df -h | grep -E '^/dev/' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local avail=$(echo "$line" | awk '{print $4}')
        local use_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mount=$(echo "$line" | awk '{print $6}')
        
        # Определяем статус
        local status="OK"
        if [ "$use_percent" -ge "$CRITICAL_THRESHOLD" ]; then
            status="CRITICAL"
            has_critical=1
        elif [ "$use_percent" -ge "$WARNING_THRESHOLD" ]; then
            status="WARN"
            has_warning=1
        fi
        
        print_status "$status" "$device: $used/$size ($use_percent%) на $mount"
    done
    
    # Информация о блочных устройствах
    echo ""
    echo "  🔧 Детальная информация о блочных устройствах:"
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL | head -15 | while read -r line; do
            echo "    📟 $line"
        done
    else
        echo "    ℹ️  Команда lsblk не найдена"
    fi
    
    # Информация о LVM (если есть)
    echo ""
    echo "  💽 Информация о LVM:"
    if command -v pvs >/dev/null 2>&1 && sudo pvs &>/dev/null; then
        echo "    📊 Physical Volumes:"
        sudo pvs 2>/dev/null | head -5 | while read -r line; do
            echo "      💾 $line"
        done || echo "      ℹ️  LVM не настроен или нет прав"
    else
        echo "    ℹ️  LVM не настроен"
    fi
    
    return $((has_critical + has_warning))
}

# Детальный анализ файловой системы
analyze_filesystems_detailed() {
    print_section "ДЕТАЛЬНЫЙ АНАЛИЗ ФАЙЛОВЫХ СИСТЕМ"
    
    echo "  📋 Типы файловых систем:"
    mount | grep -E '^/dev/' | awk '{print $5}' | sort | uniq -c | sort -nr | while read -r count fs_type; do
        echo "    💾 $fs_type: $count точек монтирования"
    done
    
    # Проверка на read-only файловые системы
    echo ""
    echo "  🔒 Проверка файловых систем на read-only:"
    local ro_count=0
    while IFS= read -r mount_line; do
        if [[ "$mount_line" == *"(ro,"* ]]; then
            ro_count=$((ro_count + 1))
            local device=$(echo "$mount_line" | awk '{print $1}')
            local mount_point=$(echo "$mount_line" | awk '{print $3}')
            print_status "WARN" "Read-only файловая система: $device на $mount_point"
        fi
    done < <(mount | grep -E '^/dev/')
    
    if [ "$ro_count" -eq 0 ]; then
        print_status "OK" "Нет read-only файловых систем"
    fi
    
    # Проверка параметров монтирования
    echo ""
    echo "  ⚙️  Параметры монтирования важных файловых систем:"
    for mount_point in "/" "/home" "/var" "/tmp"; do
        if mount | grep -q " on $mount_point "; then
            local options=$(mount | grep " on $mount_point " | awk -F'[()]' '{print $2}')
            echo "    📂 $mount_point: $options"
        fi
    done
}

# Расширенный анализ inodes
check_inodes_detailed() {
    print_section "РАСШИРЕННЫЙ АНАЛИЗ INODES"
    
    echo "  🔍 Детальное использование inodes:"
    local has_critical_inodes=0
    local has_warning_inodes=0
    
    df -i | grep -E '^/dev/' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local itotal=$(echo "$line" | awk '{print $2}')
        local iused=$(echo "$line" | awk '{print $3}')
        local ipercent=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mount=$(echo "$line" | awk '{print $6}')
        
        if [[ "$ipercent" =~ ^[0-9]+$ ]]; then
            local status="OK"
            if [ "$ipercent" -ge "$INODE_CRITICAL_THRESHOLD" ]; then
                status="CRITICAL"
                has_critical_inodes=1
            elif [ "$ipercent" -ge "$INODE_WARNING_THRESHOLD" ]; then
                status="WARN"
                has_warning_inodes=1
            fi
            
            local iused_pretty=$(printf "%'d" "$iused" 2>/dev/null || echo "$iused")
            local itotal_pretty=$(printf "%'d" "$itotal" 2>/dev/null || echo "$itotal")
            
            print_status "$status" "$device: $iused_pretty/$itotal_pretty inodes ($ipercent%) на $mount"
        fi
    done
    
    # Поиск директорий с большим количеством файлов
    echo ""
    echo "  📁 Поиск директорий с большим количеством файлов:"
    for directory in "/var" "/home" "/tmp"; do
        if [ -d "$directory" ]; then
            local file_count=$(find "$directory" -type f 2>/dev/null | wc -l 2>/dev/null || echo "0")
            local dir_count=$(find "$directory" -type d 2>/dev/null | wc -l 2>/dev/null || echo "0")
            
            if [ "$file_count" -gt 10000 ]; then
                print_status "INFO" "$directory: $file_count файлов, $dir_count директорий"
            fi
        fi
    done
    
    return $((has_critical_inodes + has_warning_inodes))
}

# Умный поиск больших файлов
find_large_files_advanced() {
    local top_count=${1:-10}
    
    print_section "ПОИСК БОЛЬШИХ ФАЙЛОВ (ТОП-$top_count)"
    
    echo "  🔎 Поиск файлов больше ${LARGE_FILE_THRESHOLD_MB}M в системе..."
    
    # Строим команду find с исключениями
    local find_cmd=("find" "/" "-type" "f" "-size" "+${LARGE_FILE_THRESHOLD_MB}M" "!" "-path" "*/proc/*" "!" "-path" "*/sys/*")
    
    # Добавляем исключения из конфигурации
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        find_cmd+=("!" "-name" "$pattern")
    done
    
    # Выполняем поиск и сортировку
    local large_files=$("${find_cmd[@]}" 2>/dev/null | xargs du -h 2>/dev/null | sort -rh | head -n "$top_count" 2>/dev/null || true)
    
    if [ -n "$large_files" ]; then
        echo "$large_files" | while read -r size file; do
            echo "    📁 $size - $file"
        done
    else
        echo "    ℹ️  Большие файлы не найдены или нет прав доступа"
    fi
    
    # Анализ домашних директорий
    echo ""
    echo "  🏠 Анализ домашних директорий (файлы > ${HOME_LARGE_FILE_THRESHOLD_MB}M):"
    if [ -d "/home" ]; then
        local home_files=$(find "/home" -type f -size "+${HOME_LARGE_FILE_THRESHOLD_MB}M" 2>/dev/null | xargs du -h 2>/dev/null | sort -rh | head -n 5 2>/dev/null || true)
        
        if [ -n "$home_files" ]; then
            echo "$home_files" | while read -r size file; do
                echo "    🏠 $size - $file"
            done
        else
            echo "    ℹ️  Большие файлы в /home не найдены"
        fi
    fi
    
    # Использование ncdu для интерактивного анализа (если доступно)
    if command -v ncdu >/dev/null 2>&1; then
        echo ""
        echo "  📊 Для интерактивного анализа используйте: ncdu /"
    fi
}

# Расширенная проверка SMART
check_smart_detailed() {
    if [ "$ENABLE_SMART_MONITORING" != "true" ]; then
        return 0
    fi
    
    print_section "РАСШИРЕННАЯ ПРОВЕРКА SMART"
    
    if ! command -v smartctl >/dev/null 2>&1; then
        print_status "WARN" "smartctl не установлен"
        echo "    💡 Установите: sudo apt install smartmontools"
        return 0
    fi
    
    local has_errors=0
    
    # Проверяем все диски
    for device in /dev/sd? /dev/nvme?n1 /dev/mmcblk?; do
        if [ -b "$device" ]; then
            echo "  🔍 Проверка $device..."
            
            # Проверяем поддержку SMART
            if smartctl -i "$device" 2>/dev/null | grep -q "SMART support is: Available"; then
                # Получаем общий статус здоровья
                local health_status=$(smartctl -H "$device" 2>/dev/null | grep "SMART overall-health" || true)
                
                if [ -n "$health_status" ]; then
                    if echo "$health_status" | grep -q "PASSED"; then
                        print_status "OK" "$device: SMART статус в норме"
                        
                        # Дополнительная информация о диске
                        local model=$(smartctl -i "$device" 2>/dev/null | grep "Device Model" | cut -d: -f2 | sed 's/^ *//' || echo "N/A")
                        local serial=$(smartctl -i "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | sed 's/^ *//' || echo "N/A")
                        local capacity=$(smartctl -i "$device" 2>/dev/null | grep "User Capacity" | cut -d: -f2 | sed 's/^ *//' || echo "N/A")
                        
                        echo "      💾 Модель: $model"
                        echo "      🔢 Серийный: $serial"
                        echo "      💽 Емкость: $capacity"
                        
                        # Проверка основных атрибутов
                        local temp=$(smartctl -A "$device" 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}' || echo "N/A")
                        if [ "$temp" != "N/A" ]; then
                            echo "      🌡️  Температура: ${temp}°C"
                        fi
                        
                    else
                        print_status "CRITICAL" "$device: ПРОБЛЕМЫ СО SMART!"
                        has_errors=1
                    fi
                else
                    print_status "WARN" "$device: Не удалось получить SMART статус"
                fi
            else
                echo "    ℹ️  $device: SMART не поддерживается"
            fi
            echo ""
        fi
    done
    
    if [ $has_errors -eq 0 ]; then
        print_status "OK" "SMART проверка завершена без критических ошибок"
    else
        print_status "ERROR" "Обнаружены проблемы с дисками!"
    fi
    
    return $has_errors
}

# Мониторинг I/O с детальной статистикой
monitor_io_detailed() {
    if [ "$ENABLE_IO_MONITORING" != "true" ]; then
        return 0
    fi
    
    print_section "ДЕТАЛЬНЫЙ МОНИТОРИНГ I/O"
    
    echo "  📈 Активность дисков (обновление каждые 2 секунды)..."
    echo -e "  ${CYAN}Для выхода нажмите Ctrl+C${NC}"
    echo ""
    
    if command -v iostat >/dev/null 2>&1; then
        iostat -dxm 2
    elif command -v vmstat >/dev/null 2>&1; then
        echo "    📊 Используем vmstat (iostat не найден):"
        vmstat 2
    else
        print_status "WARN" "iostat/vmstat не установлены"
        echo "    💡 Установите: sudo apt install sysstat"
    fi
}

# Расширенная очистка временных файлов
clean_temp_files_advanced() {
    print_section "РАСШИРЕННАЯ ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ"
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp" 
        "$HOME/.cache"
        "/var/cache/apt/archives"
        "/var/log"
    )
    
    local total_freed=0
    local total_files=0
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "  🧹 Очистка $dir..."
            
            # Подсчет файлов перед очисткой
            local files_before=$(find "$dir" -type f -atime "+$TEMP_FILE_AGE_DAYS" 2>/dev/null | wc -l || echo 0)
            local size_before=$(du -s "$dir" 2>/dev/null | cut -f1 || echo 0)
            
            # Безопасная очистка старых файлов
            find "$dir" -type f -atime "+$TEMP_FILE_AGE_DAYS" -delete 2>/dev/null || true
            
            # Очистка пустых директорий (кроме системных)
            if [[ "$dir" != "/tmp" && "$dir" != "/var/tmp" ]]; then
                find "$dir" -type d -empty -delete 2>/dev/null || true
            fi
            
            local size_after=$(du -s "$dir" 2>/dev/null | cut -f1 || echo 0)
            local freed=$((size_before - size_after))
            total_freed=$((total_freed + freed))
            total_files=$((total_files + files_before))
            
            if [ "$freed" -gt 0 ]; then
                echo "    📊 Удалено файлов: $files_before, Освобождено: $(human_size $((freed * 1024)))"
            else
                echo "    ℹ️  Нечего очищать"
            fi
        fi
    done
    
    # Очистка логов
    echo ""
    echo "  📋 Очистка старых логов:"
    if [ -d "/var/log" ]; then
        local log_files=$(find "/var/log" -name "*.log.*" -type f -mtime "+$LOG_FILE_AGE_DAYS" 2>/dev/null | wc -l || echo 0)
        find "/var/log" -name "*.log.*" -type f -mtime "+$LOG_FILE_AGE_DAYS" -delete 2>/dev/null || true
        echo "    🗑️  Удалено старых логов: $log_files"
    fi
    
    if [ "$total_freed" -gt 0 ]; then
        print_status "OK" "Очистка завершена. Освобождено: $(human_size $((total_freed * 1024)))"
        echo "    📁 Всего удалено файлов: $total_files"
    else
        print_status "INFO" "Нечего очищать"
    fi
}

# Проверка ошибок диска в системных логах
check_disk_errors_detailed() {
    print_section "ПРОВЕРКА ОШИБОК ДИСКА В ЛОГАХ"
    
    echo "  🔍 Поиск ошибок диска в системных логах..."
    
    # Проверка dmesg на ошибки диска
    local disk_errors=$(dmesg 2>/dev/null | grep -i -E "error.*disk|disk.*error|I/O error|SATA link down" | head -10 || true)
    
    if [ -n "$disk_errors" ]; then
        print_status "ERROR" "Обнаружены ошибки диска в dmesg:"
        echo "$disk_errors" | while read -r error; do
            echo "    ❌ $error"
        done
    else
        print_status "OK" "Ошибки диска в dmesg не обнаружены"
    fi
    
    # Проверка системных логов
    echo ""
    echo "  📋 Проверка системных логов:"
    local syslog_errors=$(grep -i -E "disk error|I/O error|filesystem error" /var/log/syslog /var/log/messages 2>/dev/null | head -5 || true)
    
    if [ -n "$syslog_errors" ]; then
        print_status "WARN" "Обнаружены ошибки в системных логах:"
        echo "$syslog_errors" | while read -r error; do
            echo "    ⚠️  $error"
        done
    else
        print_status "OK" "Ошибки в системных логах не обнаружены"
    fi
}

# Создание отчета
generate_report() {
    local report_file="$REPORTS_DIR/disk-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "СОЗДАНИЕ ОТЧЕТА"
    
    {
        echo "Отчет анализа дисков"
        echo "Сгенерирован: $(date)"
        echo "Система: $(uname -a)"
        echo ""
        echo "=== ИНФОРМАЦИЯ О ДИСКАХ ==="
        df -h
        echo ""
        echo "=== ИНФОРМАЦИЯ О INODES ==="
        df -i
        echo ""
        echo "=== БЛОЧНЫЕ УСТРОЙСТВА ==="
        lsblk 2>/dev/null || echo "lsblk не доступен"
        echo ""
        echo "=== SMART СТАТУС ==="
        for device in /dev/sd?; do
            if [ -b "$device" ]; then
                echo "--- $device ---"
                smartctl -H "$device" 2>/dev/null || echo "SMART не доступен"
                echo ""
            fi
        done
    } > "$report_file"
    
    print_status "OK" "Отчет создан: $report_file"
    echo "$report_file"
}

# Основная функция - полный анализ
full_analysis() {
    if ! check_dependencies; then
        exit 1
    fi
    
    print_header
    log "Запуск полного анализа дисков"
    
    local disk_status=0
    local inode_status=0
    local smart_status=0
    
    get_disk_info; disk_status=$?
    analyze_filesystems_detailed
    check_inodes_detailed; inode_status=$?
    find_large_files_advanced 8
    check_smart_detailed; smart_status=$?
    check_disk_errors_detailed
    
    local report_file=$(generate_report)
    
    echo ""
    if [ $((disk_status + inode_status + smart_status)) -eq 0 ]; then
        print_status "OK" "Анализ дисков завершен успешно"
    else
        print_status "WARN" "Обнаружены проблемы, проверьте отчет"
    fi
    
    echo ""
    echo -e "${CYAN}📝 Подробный отчет: $report_file${NC}"
    echo -e "${CYAN}📋 Логи: $LOG_FILE${NC}"
}

# Команды
cmd_monitor() {
    print_header
    monitor_io_detailed
}

cmd_clean() {
    print_header
    clean_temp_files_advanced
}

cmd_large_files() {
    local count=${2:-15}
    print_header
    find_large_files_advanced "$count"
}

cmd_info() {
    print_header
    get_disk_info
    check_inodes_detailed
    analyze_filesystems_detailed
}

cmd_smart() {
    print_header
    check_smart_detailed
}

cmd_report() {
    print_header
    generate_report
}

cmd_config() {
    print_header
    create_config
}

cmd_help() {
    print_header
    echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  monitor          - детальный мониторинг I/O в реальном времени"
    echo "  clean            - расширенная очистка временных файлов"
    echo "  large-files [N]  - поиск N самых больших файлов (по умолчанию 15)"
    echo "  info             - краткая информация о дисках"
    echo "  smart            - детальная проверка SMART статуса"
    echo "  report           - создание подробного отчета"
    echo "  config           - создание конфигурационного файла"
    echo "  help             - эта справка"
    echo ""
    echo "Без аргументов: полный анализ дисков и файловых систем"
    echo ""
    echo "Примеры:"
    echo "  $0                      # Полный анализ"
    echo "  $0 monitor              # Мониторинг в реальном времени"
    echo "  $0 clean                # Очистка временных файлов"
    echo "  $0 large-files 20       # 20 самых больших файлов"
    echo "  $0 smart                # Проверка SMART статуса"
    echo "  $0 report               # Создание отчета"
    echo "  $0 config               # Создание конфигурации"
}

# Обработка аргументов
case "${1:-}" in
    "monitor") cmd_monitor ;;
    "clean") cmd_clean ;;
    "large-files") cmd_large_files "$@" ;;
    "info") cmd_info ;;
    "smart") cmd_smart ;;
    "report") cmd_report ;;
    "config") cmd_config ;;
    "help"|"--help"|"-h") cmd_help ;;
    *) full_analysis ;;
esac
