#!/bin/bash
# 🔄 Продвинутый мониторинг процессов с аналитикой и управлением
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
CACHE_DIR="$PROJECT_ROOT/cache"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$CACHE_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Конфигурация
CONFIG_FILE="$CONFIG_DIR/process-monitor.conf"
MAIN_LOG="$LOG_DIR/process-monitor.log"
CACHE_FILE="$CACHE_DIR/process-cache.db"
ALERT_THRESHOLDS="$CONFIG_DIR/process-thresholds.conf"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🔄 ==========================================="
    echo "   ПРОДВИНУТЫЙ МОНИТОРИНГ ПРОЦЕССОВ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📊 $1${NC}"
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

print_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

print_debug() {
    echo -e "${ORANGE}🐛 $1${NC}"
}

# Логирование
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
}

# Создание конфигурации
create_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Конфигурация мониторинга процессов v2.0

# Основные настройки
MONITOR_INTERVAL=3
REFRESH_RATE=2
ENABLE_COLORS=true
SAVE_REPORTS=true
REPORT_RETENTION_DAYS=7

# Настройки мониторинга
ENABLE_PROCESS_TREE=true
ENABLE_RESOURCE_MONITOR=true
ENABLE_SERVICE_MONITOR=true
ENABLE_CONTAINER_MONITOR=true
SHOW_PROCESS_DETAILS=true

# Пороги для оповещений
CPU_CRITICAL=90
CPU_WARNING=80
MEMORY_CRITICAL=90
MEMORY_WARNING=80
PROCESS_COUNT_WARNING=500
ZOMBIE_PROCESS_WARNING=1

# Настройки фильтрации
SHOW_SYSTEM_PROCESSES=false
SHOW_USER_PROCESSES=true
FILTER_BY_USER=""
EXCLUDE_PATTERNS=("kworker/*" "ksoftirqd/*" "migration/*")

# Настройки безопасности
MONITOR_SUDO_PROCESSES=true
DETECT_SUSPICIOUS_PROCESSES=true
ALERT_ON_NEW_PROCESSES=false
CHECK_PROCESS_INTEGRITY=false

# Настройки производительности
ENABLE_CACHING=true
CACHE_TTL=10
MAX_PROCESS_DISPLAY=20
COMPACT_DISPLAY=false

# Настройки управления процессами
ENABLE_PROCESS_CONTROL=true
REQUIRE_CONFIRMATION=true
LOG_PROCESS_CHANGES=true

# Настройки аналитики
TRACK_PROCESS_HISTORY=true
ANALYZE_PROCESS_BEHAVIOR=true
DETECT_ANOMALIES=true
GENERATE_STATISTICS=true
EOF

    # Создание файла с порогами
    cat > "$ALERT_THRESHOLDS" << 'EOF'
# Пороги для оповещений о процессах

# Критические процессы (всегда показывать)
CRITICAL_PROCESSES=(
    "init"
    "systemd"
    "sshd"
    "nginx"
    "apache"
    "mysql"
    "postgres"
    "docker"
    "kubelet"
)

# Подозрительные паттерны (вызывают предупреждения)
SUSPICIOUS_PATTERNS=(
    "miner"
    "cryptocurrency"
    "malware"
    "backdoor"
    "rootkit"
    ".*sh -c"
    "wget.*http"
    "curl.*http"
)

# Процессы с высоким приоритетом
HIGH_PRIORITY_PROCESSES=(
    "kernel"
    "system"
    "dbus"
    "network"
)

# Игнорируемые процессы (не показывать в предупреждениях)
IGNORED_PROCESSES=(
    "ps"
    "top"
    "htop"
    "grep"
    "awk"
    "sed"
)
EOF

    print_success "Конфигурационные файлы созданы:"
    print_success "  $CONFIG_FILE"
    print_success "  $ALERT_THRESHOLDS"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        MONITOR_INTERVAL=3
        REFRESH_RATE=2
        ENABLE_PROCESS_TREE=true
        ENABLE_RESOURCE_MONITOR=true
        CPU_CRITICAL=90
        CPU_WARNING=80
        MEMORY_CRITICAL=90
        MEMORY_WARNING=80
        ENABLE_CACHING=true
        CACHE_TTL=10
    fi

    if [ -f "$ALERT_THRESHOLDS" ]; then
        source "$ALERT_THRESHOLDS"
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in ps grep awk sort head tail; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты
    if ! command -v pstree &> /dev/null; then
        optional_missing+=("pstree")
    fi
    
    if ! command -v lsof &> /dev/null; then
        optional_missing+=("lsof")
    fi
    
    if ! command -v htop &> /dev/null; then
        optional_missing+=("htop")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        print_warning "Отсутствуют опциональные утилиты: ${optional_missing[*]}"
        echo "💡 Для расширенных функций установите: sudo apt install ${optional_missing[*]}"
    fi
    
    return 0
}

# Кэширование
cache_set() {
    local key=$1
    local value=$2
    local ttl=${3:-$CACHE_TTL}
    local expire=$(( $(date +%s) + ttl ))
    
    if [ "$ENABLE_CACHING" = "true" ]; then
        echo "$key|$value|$expire" >> "$CACHE_FILE"
    fi
}

cache_get() {
    local key=$1
    local current_time=$(date +%s)
    local temp_file=$(mktemp)
    
    if [ ! -f "$CACHE_FILE" ] || [ "$ENABLE_CACHING" != "true" ]; then
        return 1
    fi
    
    local found=0
    while IFS='|' read -r cache_key value expire; do
        if [ "$current_time" -lt "$expire" ]; then
            if [ "$cache_key" = "$key" ]; then
                echo "$value"
                found=1
            fi
            echo "$cache_key|$value|$expire" >> "$temp_file"
        fi
    done < "$CACHE_FILE"
    
    if [ -f "$temp_file" ]; then
        mv "$temp_file" "$CACHE_FILE"
    fi
    
    [ "$found" -eq 1 ] && return 0 || return 1
}

# Получение статистики системы
get_system_stats() {
    print_section "СТАТИСТИКА СИСТЕМЫ"
    
    # Общее количество процессов
    local total_processes=$(ps -e --no-headers | wc -l)
    local user_processes=$(ps -u $(whoami) --no-headers 2>/dev/null | wc -l || echo "0")
    local zombie_processes=$(ps -e -o stat --no-headers | grep -c Z)
    
    echo "  📈 Общее количество процессов: $total_processes"
    echo "  👤 Пользовательских процессов: $user_processes"
    
    if [ "$zombie_processes" -gt 0 ]; then
        print_warning "  🧟 Zombie процессов: $zombie_processes"
    else
        echo "  🧟 Zombie процессов: 0"
    fi
    
    # Загрузка системы
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo "  📊 Нагрузка системы: $load_avg"
    
    # Использование памяти процессами
    local total_memory=$(free -m | grep Mem: | awk '{print $2}')
    local used_memory=$(free -m | grep Mem: | awk '{print $3}')
    local memory_percent=$((used_memory * 100 / total_memory))
    
    echo -n "  🧠 Использование памяти: ${memory_percent}%"
    if [ "$memory_percent" -ge "$MEMORY_CRITICAL" ]; then
        print_error " 🚨 КРИТИЧЕСКИЙ"
    elif [ "$memory_percent" -ge "$MEMORY_WARNING" ]; then
        print_warning " ⚠️  ВЫСОКИЙ"
    else
        print_success " ✅ НОРМА"
    fi
}

# Анализ процессов по CPU
analyze_cpu_processes() {
    print_section "ТОП ПРОЦЕССОВ ПО CPU"
    
    local top_cpu_processes=$(ps aux --sort=-%cpu | head -$((MAX_PROCESS_DISPLAY + 1)) | tail -n +2)
    local counter=0
    
    echo "  🏆 Топ-$MAX_PROCESS_DISPLAY процессов по использованию CPU:"
    echo ""
    echo "    PID     USER      CPU%    MEM%    COMMAND"
    echo "    ──────────────────────────────────────────"
    
    while IFS= read -r process; do
        counter=$((counter + 1))
        local pid=$(echo "$process" | awk '{print $2}')
        local user=$(echo "$process" | awk '{print $1}')
        local cpu=$(echo "$process" | awk '{print $3}')
        local mem=$(echo "$process" | awk '{print $4}')
        local command=$(echo "$process" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
        
        # Обрезаем длинные команды
        if [ ${#command} -gt 50 ]; then
            command="${command:0:47}..."
        fi
        
        echo -n "    $pid     $user     $cpu%     $mem%    $command"
        
        # Цветовое кодирование для высокого использования CPU
        if (( $(echo "$cpu >= $CPU_CRITICAL" | bc -l 2>/dev/null || echo "0") )); then
            print_error " 🚨"
        elif (( $(echo "$cpu >= $CPU_WARNING" | bc -l 2>/dev/null || echo "0") )); then
            print_warning " ⚠️"
        else
            echo ""
        fi
    done <<< "$top_cpu_processes"
}

# Анализ процессов по памяти
analyze_memory_processes() {
    print_section "ТОП ПРОЦЕССОВ ПО ПАМЯТИ"
    
    local top_mem_processes=$(ps aux --sort=-%mem | head -$((MAX_PROCESS_DISPLAY + 1)) | tail -n +2)
    local counter=0
    
    echo "  🏆 Топ-$MAX_PROCESS_DISPLAY процессов по использованию памяти:"
    echo ""
    echo "    PID     USER      MEM%    CPU%    COMMAND"
    echo "    ──────────────────────────────────────────"
    
    while IFS= read -r process; do
        counter=$((counter + 1))
        local pid=$(echo "$process" | awk '{print $2}')
        local user=$(echo "$process" | awk '{print $1}')
        local mem=$(echo "$process" | awk '{print $4}')
        local cpu=$(echo "$process" | awk '{print $3}')
        local command=$(echo "$process" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
        
        # Обрезаем длинные команды
        if [ ${#command} -gt 50 ]; then
            command="${command:0:47}..."
        fi
        
        echo -n "    $pid     $user     $mem%     $cpu%    $command"
        
        # Цветовое кодирование для высокого использования памяти
        if (( $(echo "$mem >= $MEMORY_CRITICAL" | bc -l 2>/dev/null || echo "0") )); then
            print_error " 🚨"
        elif (( $(echo "$mem >= $MEMORY_WARNING" | bc -l 2>/dev/null || echo "0") )); then
            print_warning " ⚠️"
        else
            echo ""
        fi
    done <<< "$top_mem_processes"
}

# Детальная информация о процессе
get_process_details() {
    local pid=$1
    
    if [ -z "$pid" ]; then
        print_error "Укажите PID процесса"
        return 1
    fi
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        print_error "Процесс с PID $pid не существует"
        return 1
    fi
    
    print_section "ДЕТАЛЬНАЯ ИНФОРМАЦИЯ О ПРОЦЕССЕ: $pid"
    
    # Базовая информация
    echo "  📋 Базовая информация:"
    ps -p "$pid" -o pid,user,pcpu,pmem,vsz,rss,tty,stat,start,time,comm --no-headers 2>/dev/null | while read -r line; do
        echo "    🆔 $line"
    done
    
    # Командная строка
    echo "  💻 Командная строка:"
    local cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ' || echo "не доступно")
    echo "    $cmdline"
    
    # Использование ресурсов
    echo "  📊 Использование ресурсов:"
    local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | awk '{print $1}')
    local mem_usage=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | awk '{print $1}')
    local vsz=$(ps -p "$pid" -o vsz --no-headers 2>/dev/null | awk '{print $1}')
    local rss=$(ps -p "$pid" -o rss --no-headers 2>/dev/null | awk '{print $1}')
    
    echo "    💻 CPU: ${cpu_usage:-0}%"
    echo "    🧠 Память: ${mem_usage:-0}%"
    echo "    💾 Виртуальная память: ${vsz:-0} KB"
    echo "    📝 Физическая память: ${rss:-0} KB"
    
    # Открытые файлы (если доступно)
    if command -v lsof &> /dev/null; then
        echo "  📁 Открытые файлы (первые 5):"
        lsof -p "$pid" 2>/dev/null | head -6 | tail -n +2 | while read -r line; do
            echo "    📄 $line"
        done
    fi
    
    # Информация из /proc
    if [ -d "/proc/$pid" ]; then
        echo "  🔍 Информация из /proc:"
        local environ_count=$(cat /proc/"$pid"/environ 2>/dev/null | tr '\0' '\n' | wc -l)
        local fd_count=$(ls /proc/"$pid"/fd 2>/dev/null | wc -l)
        
        echo "    🌍 Переменных окружения: $environ_count"
        echo "    🔗 Открытых файловых дескрипторов: $fd_count"
    fi
}

# Поиск процессов
find_processes() {
    local pattern=$1
    local user=$2
    
    if [ -z "$pattern" ]; then
        print_error "Укажите шаблон для поиска"
        return 1
    fi
    
    print_section "ПОИСК ПРОЦЕССОВ: $pattern"
    
    local search_cmd="ps aux"
    
    if [ -n "$user" ]; then
        search_cmd="$search_cmd -u $user"
    fi
    
    local results=$(eval "$search_cmd" | grep -i "$pattern" | grep -v grep)
    
    if [ -z "$results" ]; then
        print_info "Процессы не найдены"
        return 0
    fi
    
    echo "  🔍 Найдено процессов: $(echo "$results" | wc -l)"
    echo ""
    echo "    PID     USER      CPU%    MEM%    COMMAND"
    echo "    ──────────────────────────────────────────"
    
    while IFS= read -r process; do
        local pid=$(echo "$process" | awk '{print $2}')
        local user=$(echo "$process" | awk '{print $1}')
        local cpu=$(echo "$process" | awk '{print $3}')
        local mem=$(echo "$process" | awk '{print $4}')
        local command=$(echo "$process" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
        
        # Обрезаем длинные команды
        if [ ${#command} -gt 60 ]; then
            command="${command:0:57}..."
        fi
        
        echo "    $pid     $user     $cpu%     $mem%    $command"
    done <<< "$results"
}

# Дерево процессов
show_process_tree() {
    if [ "$ENABLE_PROCESS_TREE" != "true" ]; then
        return
    fi
    
    print_section "ДЕРЕВО ПРОЦЕССОВ"
    
    if command -v pstree >/dev/null 2>&1; then
        pstree -p -u -a -A
    else
        print_warning "Утилита pstree не установлена"
        echo "💡 Установите: sudo apt install psmisc"
        echo ""
        echo "📝 Альтернативный вывод:"
        ps -ejH | head -30
    fi
}

# Мониторинг в реальном времени
monitor_realtime() {
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_section "МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Обновление каждые $REFRESH_RATE секунд..."
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "  🔄 Цикл мониторинга: $counter"
        echo "  ⏰ Время: $(date '+%H:%M:%S')"
        echo "  ==================================="
        
        get_system_stats
        echo ""
        analyze_cpu_processes
        echo ""
        analyze_memory_processes
        
        # Показываем предупреждения каждые 10 циклов
        if [ $((counter % 10)) -eq 0 ]; then
            echo ""
            check_process_warnings
        fi
        
        echo ""
        echo "  ⌛ Следующее обновление через $REFRESH_RATE секунд..."
        sleep "$REFRESH_RATE"
    done
}

# Проверка предупреждений
check_process_warnings() {
    print_section "ПРОВЕРКА ПРЕДУПРЕЖДЕНИЙ"
    
    local warnings=0
    
    # Проверка zombie процессов
    local zombie_count=$(ps -e -o stat --no-headers | grep -c Z)
    if [ "$zombie_count" -gt 0 ]; then
        print_warning "Обнаружены zombie процессы: $zombie_count"
        warnings=$((warnings + 1))
    fi
    
    # Проверка процессов с высоким CPU
    local high_cpu_count=$(ps aux --sort=-%cpu | awk '{if($3>='"$CPU_WARNING"') print $0}' | wc -l)
    if [ "$high_cpu_count" -gt 1 ]; then  # -1 потому что заголовок
        print_warning "Процессы с высоким CPU: $((high_cpu_count - 1))"
        warnings=$((warnings + 1))
    fi
    
    # Проверка процессов с высоким RAM
    local high_mem_count=$(ps aux --sort=-%mem | awk '{if($4>='"$MEMORY_WARNING"') print $0}' | wc -l)
    if [ "$high_mem_count" -gt 1 ]; then
        print_warning "Процессы с высоким RAM: $((high_mem_count - 1))"
        warnings=$((warnings + 1))
    fi
    
    # Проверка подозрительных процессов
    if [ "$DETECT_SUSPICIOUS_PROCESSES" = "true" ]; then
        for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
            local suspicious_count=$(ps aux | grep -c "$pattern" | grep -v grep || true)
            if [ "$suspicious_count" -gt 0 ]; then
                print_warning "Подозрительные процессы: $suspicious_count (паттерн: $pattern)"
                warnings=$((warnings + 1))
            fi
        done
    fi
    
    if [ "$warnings" -eq 0 ]; then
        print_success "Критических проблем не обнаружено"
    fi
}

# Управление процессами
manage_process() {
    local action=$1
    local pid=$2
    
    if [ -z "$pid" ]; then
        print_error "Укажите PID процесса"
        return 1
    fi
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        print_error "Процесс с PID $pid не существует"
        return 1
    fi
    
    local process_info=$(ps -p "$pid" -o user,comm --no-headers 2>/dev/null)
    
    case $action in
        "kill")
            if [ "$REQUIRE_CONFIRMATION" = "true" ]; then
                echo -e "${YELLOW}⚠️  Вы уверены, что хотите завершить процесс $pid ($process_info)? [y/N]${NC}"
                read -r confirmation
                if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                    print_info "Отменено пользователем"
                    return 0
                fi
            fi
            
            if kill "$pid"; then
                print_success "Процесс $pid завершен"
                log_message "INFO" "Процесс $pid ($process_info) завершен пользователем"
            else
                print_error "Не удалось завершить процесс $pid"
            fi
            ;;
        
        "stop")
            if kill -STOP "$pid"; then
                print_success "Процесс $pid приостановлен"
                log_message "INFO" "Процесс $pid ($process_info) приостановлен"
            else
                print_error "Не удалось приостановить процесс $pid"
            fi
            ;;
        
        "continue")
            if kill -CONT "$pid"; then
                print_success "Процесс $pid возобновлен"
                log_message "INFO" "Процесс $pid ($process_info) возобновлен"
            else
                print_error "Не удалось возобновить процесс $pid"
            fi
            ;;
        
        "priority")
            local priority=$3
            if [ -z "$priority" ]; then
                print_error "Укажите приоритет (от -20 до 19)"
                return 1
            fi
            
            if renice "$priority" "$pid"; then
                print_success "Приоритет процесса $pid изменен на $priority"
                log_message "INFO" "Приоритет процесса $pid ($process_info) изменен на $priority"
            else
                print_error "Не удалось изменить приоритет процесса $pid"
            fi
            ;;
        
        *)
            print_error "Неизвестное действие: $action"
            return 1
            ;;
    esac
}

# Анализ использования ресурсов
analyze_resource_usage() {
    print_section "АНАЛИЗ ИСПОЛЬЗОВАНИЯ РЕСУРСОВ"
    
    # Общее использование CPU процессами
    local total_cpu=$(ps -eo pcpu --no-headers | awk '{sum+=$1} END {print sum}')
    echo "  💻 Общее использование CPU процессами: ${total_cpu:-0}%"
    
    # Общее использование памяти процессами
    local total_mem=$(ps -eo pmem --no-headers | awk '{sum+=$1} END {print sum}')
    echo "  🧠 Общее использование памяти процессами: ${total_mem:-0}%"
    
    # Распределение процессов по пользователям
    echo "  👥 Распределение процессов по пользователям:"
    ps -eo user --no-headers | sort | uniq -c | sort -nr | head -5 | while read -r count user; do
        echo "    👤 $user: $count процессов"
    done
    
    # Самые старые процессы
    echo "  🕐 Самые старые процессы:"
    ps -eo pid,user,etime,comm --sort=etime --no-headers | head -5 | while read -r pid user etime comm; do
        echo "    ⏳ $pid ($user): $comm - $etime"
    done
}

# Генерация отчета
generate_report() {
    local report_file="$REPORTS_DIR/process-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ ОТЧЕТА"
    
    print_header > "$report_file"
    echo "📅 Отчет создан: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    get_system_stats >> "$report_file" 2>&1
    echo "" >> "$report_file"
    analyze_cpu_processes >> "$report_file" 2>&1
    echo "" >> "$report_file"
    analyze_memory_processes >> "$report_file" 2>&1
    echo "" >> "$report_file"
    analyze_resource_usage >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_process_warnings >> "$report_file" 2>&1
    
    print_success "Отчет сохранен: $report_file"
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "monitor")
            print_header
            monitor_realtime
            ;;
        "top")
            print_header
            get_system_stats
            analyze_cpu_processes
            analyze_memory_processes
            ;;
        "find")
            print_header
            find_processes "${2:-}" "${3:-}"
            ;;
        "info")
            print_header
            get_process_details "${2:-}"
            ;;
        "tree")
            print_header
            show_process_tree
            ;;
        "kill")
            manage_process "kill" "${2:-}"
            ;;
        "stop")
            manage_process "stop" "${2:-}"
            ;;
        "continue")
            manage_process "continue" "${2:-}"
            ;;
        "priority")
            manage_process "priority" "${2:-}" "${3:-}"
            ;;
        "analyze")
            print_header
            analyze_resource_usage
            check_process_warnings
            ;;
        "report")
            print_header
            generate_report
            ;;
        "config")
            create_config
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  monitor               - Мониторинг в реальном времени"
            echo "  top                   - Статичный топ процессов"
            echo "  find <шаблон> [пользователь] - Поиск процессов"
            echo "  info <PID>            - Детальная информация о процессе"
            echo "  tree                  - Дерево процессов"
            echo "  kill <PID>            - Завершить процесс"
            echo "  stop <PID>            - Приостановить процесс"
            echo "  continue <PID>        - Возобновить процесс"
            echo "  priority <PID> <уровень> - Изменить приоритет"
            echo "  analyze               - Анализ использования ресурсов"
            echo "  report                - Генерация отчета"
            echo "  config                - Создать конфигурацию"
            echo "  help                  - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 monitor"
            echo "  $0 top"
            echo "  $0 find nginx"
            echo "  $0 info 1234"
            echo "  $0 kill 5678"
            echo "  $0 priority 1234 5"
            echo "  $0 analyze"
            echo "  $0 report"
            ;;
        *)
            print_header
            get_system_stats
            analyze_cpu_processes
            analyze_memory_processes
            analyze_resource_usage
            ;;
    esac
}

# Инициализация
log_message "INFO" "Запуск мониторинга процессов"
main "$@"
log_message "INFO" "Завершение работы"
