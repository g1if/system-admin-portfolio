#!/bin/bash
# 🖥️ Продвинутый системный монитор с аналитикой и прогнозированием
# Автор: g1if
# Версия: 3.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
METRICS_DIR="$PROJECT_ROOT/metrics"
LOG_FILE="$LOG_DIR/system-monitor.log"
MAIN_CONFIG="$CONFIG_DIR/system-monitor.conf"

# Создаем директории
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$METRICS_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    for cmd in awk grep sed cut bc date ps free df; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные зависимости
    if [ "$ENABLE_TEMPERATURE_MONITORING" = "true" ] && ! command -v sensors &> /dev/null; then
        echo "⚠️  Утилита 'sensors' не найдена. Мониторинг температуры отключен."
        ENABLE_TEMPERATURE_MONITORING=false
    fi
    
    if [ "$ENABLE_DETAILED_NETWORK" = "true" ] && ! command -v ip &> /dev/null; then
        echo "⚠️  Утилита 'ip' не найдена. Детальный сетевой мониторинг отключен."
        ENABLE_DETAILED_NETWORK=false
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Отсутствуют обязательные утилиты: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Логирование
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "🖥️  ==========================================="
    echo "   ПРОДВИНУТЫЙ СИСТЕМНЫЙ МОНИТОР v3.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "   Репозиторий: github.com/g1if/system-admin-portfolio"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📊 $1${NC}"
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
}

# Создание конфигурации
create_config() {
    cat > "$MAIN_CONFIG" << 'EOF'
# Конфигурация системного монитора v3.0

# Настройки мониторинга
ENABLE_TEMPERATURE_MONITORING=true
ENABLE_DETAILED_NETWORK=true
ENABLE_PROCESS_MONITORING=true
ENABLE_DISK_IO_MONITORING=true
ENABLE_SERVICE_MONITORING=true

# Пороговые значения (в процентах)
CPU_WARNING=80
CPU_CRITICAL=90
MEMORY_WARNING=80
MEMORY_CRITICAL=90
DISK_WARNING=80
DISK_CRITICAL=90
TEMPERATURE_WARNING=70
TEMPERATURE_CRITICAL=80

# Настройки мониторинга в реальном времени
MONITOR_REFRESH_RATE=5
MONITOR_TIMEOUT=300
SAVE_METRICS=true
METRICS_RETENTION_DAYS=7

# Отслеживаемые сервисы
MONITOR_SERVICES=("ssh" "nginx" "mysql" "postgresql" "docker" "apache2")

# Настройки сети
CHECK_INTERNET=true
INTERNET_TEST_HOSTS=("8.8.8.8" "1.1.1.1" "google.com")

# Настройки отчетов
REPORT_ENABLED=true
REPORT_RETENTION_DAYS=30
AUTO_GENERATE_REPORT=true

# Дополнительные настройки
CHECK_DEPENDENCIES=true
LOG_RETENTION_DAYS=30
ENABLE_ALERTS=true
EOF
    print_success "Конфигурация создана: $MAIN_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$MAIN_CONFIG" ]; then
        source "$MAIN_CONFIG"
        log "INFO" "Конфигурация загружена из $MAIN_CONFIG"
    else
        log "WARN" "Конфигурационный файл не найден. Используются значения по умолчанию."
        # Значения по умолчанию
        ENABLE_TEMPERATURE_MONITORING=true
        ENABLE_DETAILED_NETWORK=true
        ENABLE_PROCESS_MONITORING=true
        CPU_WARNING=80
        CPU_CRITICAL=90
        MEMORY_WARNING=80
        MEMORY_CRITICAL=90
        DISK_WARNING=80
        DISK_CRITICAL=90
        MONITOR_REFRESH_RATE=5
        MONITOR_SERVICES=("ssh" "nginx" "mysql")
        CHECK_INTERNET=true
        ENABLE_ALERTS=true
    fi
}

# Отправка оповещений
send_alert() {
    local level=$1
    local message=$2
    local component=${3:-""}
    
    if [ "$ENABLE_ALERTS" != "true" ]; then
        return
    fi
    
    local full_message="[$level] $message"
    if [ -n "$component" ]; then
        full_message="[$level] $component: $message"
    fi
    
    # Логирование всегда
    log "$level" "$message"
    
    # Console оповещения
    case $level in
        "CRITICAL") print_status "CRITICAL" "$message" ;;
        "ERROR") print_status "ERROR" "$message" ;;
        "WARN") print_status "WARN" "$message" ;;
        "INFO") print_status "INFO" "$message" ;;
    esac
}

# Автоопределение системных параметров
detect_system() {
    print_section "ДЕТАЛЬНАЯ СИСТЕМНАЯ ИНФОРМАЦИЯ"
    
    # Определение дистрибутива
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_PRETTY_NAME="$PRETTY_NAME"
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
        OS_PRETTY_NAME="$OS_NAME $OS_VERSION"
    fi
    
    echo "  🖥️  ОС: $OS_PRETTY_NAME"
    echo "  📛 Хостнейм: $(hostname -f 2>/dev/null || hostname)"
    echo "  🐧 Ядро: $(uname -r)"
    echo "  🏗️  Архитектура: $(uname -m)"
    echo "  👤 Пользователь: $(whoami)"
    
    # Uptime
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Не доступно")
    BOOT_TIME=$(date -d "$(uptime -s 2>/dev/null)" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Не доступно")
    echo "  ⏰ Время работы: $UPTIME"
    echo "  🚀 Время загрузки: $BOOT_TIME"
    
    # Информация о процессоре
    if [ -f /proc/cpuinfo ]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        CPU_CORES=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo)
        echo "  🔧 Процессор: $CPU_MODEL"
        echo "  🎯 Ядер/потоков: $CPU_CORES"
    fi
    
    # Информация о памяти
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        MEM_TOTAL_GB=$((MEM_TOTAL_KB / 1024 / 1024))
        SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        SWAP_TOTAL_GB=$((SWAP_TOTAL_KB / 1024 / 1024))
        echo "  💾 Оперативная память: ${MEM_TOTAL_GB}GB"
        echo "  💽 Swap: ${SWAP_TOTAL_GB}GB"
    fi
}

# Расширенный мониторинг ресурсов
check_resources() {
    print_section "РАСШИРЕННЫЙ МОНИТОРИНГ РЕСУРСОВ"
    
    # CPU с детальной информацией
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    local cpu_usage=0
    local load_avg=$(awk '{print $1","$2","$3}' /proc/loadavg 2>/dev/null || echo "N/A")
    
    if command -v mpstat &> /dev/null; then
        cpu_usage=$(mpstat 1 1 2>/dev/null | awk '$3 ~ /[0-9.]+/ {print 100 - $3}' | tail -1)
        cpu_usage=$(printf "%.1f" "$cpu_usage")
    elif command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        cpu_usage=$(printf "%.1f" "$cpu_usage")
    else
        # Простой расчет через /proc/stat
        local cpu_line=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8 " " $2+$3+$4+$7+$8}' /proc/stat)
        local total=$(echo $cpu_line | awk '{print $1}')
        local idle=$(echo $cpu_line | awk '{print $2}')
        sleep 1
        local cpu_line2=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8 " " $2+$3+$4+$7+$8}' /proc/stat)
        local total2=$(echo $cpu_line2 | awk '{print $1}')
        local idle2=$(echo $cpu_line2 | awk '{print $2}')
        local total_diff=$((total2 - total))
        local idle_diff=$((idle2 - idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
    fi
    
    echo -n "  💻 CPU: ${cpu_usage}% (${load_avg}) - "
    if (( $(echo "$cpu_usage > $CPU_CRITICAL" | bc -l 2>/dev/null) )); then
        send_alert "CRITICAL" "Высокая загрузка CPU: ${cpu_usage}%" "CPU"
    elif (( $(echo "$cpu_usage > $CPU_WARNING" | bc -l 2>/dev/null) )); then
        send_alert "WARN" "Повышенная загрузка CPU: ${cpu_usage}%" "CPU"
    else
        print_status "OK" "Загрузка CPU: ${cpu_usage}%"
    fi
    
    # Детальная информация о памяти
    if command -v free &> /dev/null; then
        local mem_info=$(free -b 2>/dev/null | grep Mem)
        if [ -n "$mem_info" ]; then
            local mem_total=$(echo $mem_info | awk '{print $2}')
            local mem_used=$(echo $mem_info | awk '{print $3}')
            local mem_available=$(echo $mem_info | awk '{print $7}')
            local mem_percent=$((mem_used * 100 / mem_total))
            
            local mem_total_gb=$(echo "scale=2; $mem_total/1024/1024/1024" | bc)
            local mem_used_gb=$(echo "scale=2; $mem_used/1024/1024/1024" | bc)
            local mem_available_gb=$(echo "scale=2; $mem_available/1024/1024/1024" | bc)
            
            echo -n "  🧠 Память: ${mem_used_gb}GB/${mem_total_gb}GB (${mem_percent}%) - "
            if [ "$mem_percent" -gt "$MEMORY_CRITICAL" ] 2>/dev/null; then
                send_alert "CRITICAL" "Высокое использование памяти: ${mem_percent}%" "Memory"
            elif [ "$mem_percent" -gt "$MEMORY_WARNING" ] 2>/dev/null; then
                send_alert "WARN" "Повышенное использование памяти: ${mem_percent}%" "Memory"
            else
                print_status "OK" "Использование памяти: ${mem_percent}%"
            fi
            echo "    💡 Доступно: ${mem_available_gb}GB"
        fi
    fi
    
    # Детальная информация о дисках
    if command -v df &> /dev/null; then
        echo "  💾 Диски:"
        df -h 2>/dev/null | grep -E "^/dev/" | head -5 | while read -r line; do
            local filesystem=$(echo $line | awk '{print $1}')
            local size=$(echo $line | awk '{print $2}')
            local used=$(echo $line | awk '{print $3}')
            local avail=$(echo $line | awk '{print $4}')
            local use_percent=$(echo $line | awk '{print $5}' | sed 's/%//')
            local mount=$(echo $line | awk '{print $6}')
            
            echo -n "    $mount: $used/$size ($use_percent%) - "
            if [ "$use_percent" -gt "$DISK_CRITICAL" ] 2>/dev/null; then
                send_alert "CRITICAL" "Диск $mount заполнен на ${use_percent}%" "Disk"
            elif [ "$use_percent" -gt "$DISK_WARNING" ] 2>/dev/null; then
                send_alert "WARN" "Диск $mount заполнен на ${use_percent}%" "Disk"
            else
                print_status "OK" "Диск $mount: ${use_percent}%"
            fi
        done
    fi
    
    # Мониторинг температуры
    if [ "$ENABLE_TEMPERATURE_MONITORING" = "true" ] && command -v sensors &> /dev/null; then
        local temp_info=$(sensors 2>/dev/null | grep -E "Core|Package|temp" | grep "+" | head -1)
        if [ -n "$temp_info" ]; then
            local temp=$(echo "$temp_info" | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//')
            if [ -n "$temp" ]; then
                echo -n "  🌡️  Температура: ${temp}°C - "
                if (( $(echo "$temp > $TEMPERATURE_CRITICAL" | bc -l 2>/dev/null) )); then
                    send_alert "CRITICAL" "Высокая температура: ${temp}°C" "Temperature"
                elif (( $(echo "$temp > $TEMPERATURE_WARNING" | bc -l 2>/dev/null) )); then
                    send_alert "WARN" "Повышенная температура: ${temp}°C" "Temperature"
                else
                    print_status "OK" "Температура: ${temp}°C"
                fi
            fi
        fi
    fi
    
    # Мониторинг процессов
    if [ "$ENABLE_PROCESS_MONITORING" = "true" ]; then
        echo "  🔄 Топ процессов по CPU:"
        ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu 2>/dev/null | head -6 | while read -r line; do
            echo "    📝 $line"
        done
    fi
}

# Расширенный мониторинг сети
check_network() {
    print_section "РАСШИРЕННЫЙ СЕТЕВОЙ МОНИТОРИНГ"
    
    # Детальная информация о сетевых интерфейсах
    if [ "$ENABLE_DETAILED_NETWORK" = "true" ] && command -v ip &> /dev/null; then
        echo "  🌐 Сетевые интерфейсы:"
        ip addr show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "LOOPBACK" | head -3 | while read -r line; do
            local iface=$(echo $line | awk -F: '{print $2}' | sed 's/^ *//')
            local state=$(echo $line | grep -o "state [A-Z]\+" | awk '{print $2}')
            local mac=$(ip addr show $iface 2>/dev/null | grep "link/ether" | awk '{print $2}')
            local ipv4=$(ip addr show $iface 2>/dev/null | grep "inet " | awk '{print $2}')
            
            echo "    🔌 $iface: $state"
            if [ -n "$mac" ]; then
                echo "      📍 MAC: $mac"
            fi
            if [ -n "$ipv4" ]; then
                echo "      🌍 IPv4: $ipv4"
            fi
        done
    fi
    
    # Проверка интернета с несколькими хостами
    if [ "$CHECK_INTERNET" = "true" ]; then
        echo "  📡 Проверка интернет соединения:"
        local internet_available=0
        local tested_hosts=0
        
        for host in "${INTERNET_TEST_HOSTS[@]}"; do
            if ping -c 1 -W 2 "$host" &>/dev/null; then
                print_status "OK" "$host: Доступен"
                internet_available=1
                break
            else
                print_status "WARN" "$host: Не доступен"
            fi
            tested_hosts=$((tested_hosts + 1))
        done
        
        if [ "$internet_available" -eq 0 ]; then
            send_alert "ERROR" "Интернет соединение недоступно" "Network"
        fi
    fi
    
    # Статистика сети
    if [ -f /proc/net/dev ]; then
        echo "  📊 Сетевая статистика:"
        grep -E "(eth|en|wlan|wl)" /proc/net/dev 2>/dev/null | head -2 | while read -r line; do
            local iface=$(echo $line | awk -F: '{print $1}' | sed 's/^ *//')
            local rx_bytes=$(echo $line | awk '{print $2}')
            local tx_bytes=$(echo $line | awk '{print $10}')
            local rx_mb=$((rx_bytes / 1024 / 1024))
            local tx_mb=$((tx_bytes / 1024 / 1024))
            echo "    📥 $iface: RX=${rx_mb}MB, TX=${tx_mb}MB"
        done
    fi
}

# Расширенный мониторинг сервисов
check_services() {
    print_section "МОНИТОРИНГ СИСТЕМНЫХ СЕРВИСОВ"
    
    local service_count=0
    local running_count=0
    
    for service in "${MONITOR_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_status "OK" "$service: ✅ Запущен"
            running_count=$((running_count + 1))
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            print_status "WARN" "$service: ⚠️  Остановлен (но включен)"
        elif command -v "$service" &>/dev/null || systemctl list-unit-files | grep -q "$service"; then
            print_status "INFO" "$service: ℹ️  Установлен, но не отслеживается"
        fi
        service_count=$((service_count + 1))
    done
    
    echo "  📈 Статистика сервисов: $running_count/$service_count запущено"
    
    # Проверка неудачных сервисов
    if command -v systemctl &>/dev/null; then
        local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
        if [ "$failed_services" -gt 0 ]; then
            send_alert "ERROR" "Обнаружены неудачные сервисы: $failed_services" "Services"
            echo "  🚨 Неудачные сервисы:"
            systemctl --failed --no-legend 2>/dev/null | head -3 | while read -r line; do
                echo "    ❌ $line"
            done
        fi
    fi
}

# Сохранение метрик
save_metrics() {
    if [ "$SAVE_METRICS" != "true" ]; then
        return
    fi
    
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local metrics_file="$METRICS_DIR/metrics_${timestamp}.csv"
    
    {
        echo "timestamp,cpu_usage,memory_usage,disk_usage,temperature"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),${cpu_usage:-0},${mem_percent:-0},${use_percent:-0},${temp:-0}"
    } > "$metrics_file"
    
    log "INFO" "Метрики сохранены: $metrics_file"
}

# Генерация отчета
generate_report() {
    local report_file="$REPORTS_DIR/system-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ СИСТЕМНОГО ОТЧЕТА"
    
    {
        echo "СИСТЕМНЫЙ ОТЧЕТ"
        echo "Сгенерирован: $(date)"
        echo "Система: $(hostname)"
        echo "==========================================="
        echo ""
        
        echo "ОБЩАЯ ИНФОРМАЦИЯ:"
        echo "----------------"
        echo "ОС: $OS_PRETTY_NAME"
        echo "Ядро: $(uname -r)"
        echo "Архитектура: $(uname -m)"
        echo "Время работы: $UPTIME"
        echo ""
        
        echo "РЕСУРСЫ:"
        echo "--------"
        echo "CPU: ${cpu_usage}%"
        echo "Память: ${mem_percent}%"
        echo "Диски: см. выше"
        echo ""
        
        echo "СЕТЬ:"
        echo "-----"
        ip addr show 2>/dev/null | grep "inet " | head -5
        echo ""
        
        echo "СЕРВИСЫ:"
        echo "--------"
        systemctl list-units --type=service --state=running --no-legend 2>/dev/null | head -10
        
    } > "$report_file"
    
    print_status "OK" "Отчет сохранен: $report_file"
    log "INFO" "Сгенерирован отчет: $report_file"
}

# Режим мониторинга в реальном времени
monitor_mode() {
    if [ "$CHECK_DEPENDENCIES" = "true" ] && ! check_dependencies; then
        exit 1
    fi
    
    print_header
    echo "  🔍 РЕЖИМ МОНИТОРИНГА В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "  ⏰ Обновление каждые: $MONITOR_REFRESH_RATE сек"
    echo "  ⏱️  Таймаут: $MONITOR_TIMEOUT сек"
    echo "  💾 Сохранение метрик: $SAVE_METRICS"
    echo ""
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Проверяем таймаут
        if [ $elapsed -ge $MONITOR_TIMEOUT ]; then
            echo -e "${YELLOW}⏰ Время мониторинга истекло${NC}"
            break
        fi
        
        counter=$((counter + 1))
        clear
        print_header
        echo "  📊 Цикл мониторинга #$counter ($(date '+%H:%M:%S'))"
        echo "  ⏱️  Прошло: ${elapsed} сек"
        echo ""
        
        check_resources
        echo ""
        check_network
        echo ""
        check_services
        
        # Сохраняем метрики
        save_metrics
        
        echo ""
        echo "  ⏳ Следующее обновление через $MONITOR_REFRESH_RATE сек..."
        sleep "$MONITOR_REFRESH_RATE"
    done
}

# Быстрая проверка системы
quick_check() {
    print_header
    echo "  ⚡ БЫСТРАЯ ПРОВЕРКА СИСТЕМЫ"
    echo ""
    
    detect_system
    echo ""
    check_resources
}

# Основная функция
main() {
    load_config
    
    if [ "$CHECK_DEPENDENCIES" = "true" ] && ! check_dependencies; then
        exit 1
    fi
    
    print_header
    log "INFO" "Запуск расширенного системного монитора"
    
    detect_system
    echo ""
    check_resources
    echo ""
    check_network
    echo ""
    check_services
    
    # Сохранение метрик
    save_metrics
    
    # Автогенерация отчета
    if [ "$AUTO_GENERATE_REPORT" = "true" ]; then
        echo ""
        generate_report > /dev/null
    fi
    
    echo ""
    print_status "OK" "Расширенный мониторинг системы завершен"
    log "INFO" "Мониторинг системы завершен"
    echo ""
    echo -e "${CYAN}📝 Подробные логи: $LOG_FILE${NC}"
    echo -e "${CYAN}📊 Метрики: $METRICS_DIR/${NC}"
}

# Команды
cmd_monitor() {
    monitor_mode
}

cmd_quick() {
    quick_check
}

cmd_report() {
    print_header
    generate_report
    cat "$REPORTS_DIR/system-report-"*.txt 2>/dev/null | tail -1 | xargs cat 2>/dev/null || \
    echo "Отчеты не найдены"
}

cmd_metrics() {
    print_section "ПОСЛЕДНИЕ МЕТРИКИ СИСТЕМЫ"
    
    local latest_metric=$(ls -t "$METRICS_DIR"/metrics_*.csv 2>/dev/null | head -1)
    if [ -n "$latest_metric" ]; then
        echo "  📈 Последние записи метрик:"
        tail -5 "$latest_metric" | while read -r line; do
            echo "    📊 $line"
        done
        echo ""
        echo "  📁 Файл: $latest_metric"
    else
        echo "  ℹ️  Метрики не найдены"
        echo "  💡 Запустите мониторинг: $0 monitor"
    fi
}

cmd_config() {
    create_config
}

cmd_analyze() {
    print_header
    print_section "АНАЛИЗ СИСТЕМНЫХ ПОКАЗАТЕЛЕЙ"
    
    # Анализ трендов нагрузки
    echo "  📊 Анализ трендов нагрузки:"
    
    # CPU анализ
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    local load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
    
    if [ -n "$load_avg" ]; then
        local load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc)
        echo -n "  💻 Нагрузка системы: $load_avg (на ядро: $load_per_core) - "
        
        if (( $(echo "$load_per_core > 1.0" | bc -l) )); then
            print_status "WARN" "Высокая нагрузка на ядро"
        elif (( $(echo "$load_per_core > 0.7" | bc -l) )); then
            print_status "INFO" "Умеренная нагрузка"
        else
            print_status "OK" "Нормальная нагрузка"
        fi
    fi
    
    # Анализ памяти
    if [ -f /proc/meminfo ]; then
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_usage_percent=$(( (mem_total - mem_available) * 100 / mem_total ))
        
        echo -n "  🧠 Использование памяти: ${mem_usage_percent}% - "
        if [ "$mem_usage_percent" -gt 90 ]; then
            print_status "WARN" "Высокое использование памяти"
        elif [ "$mem_usage_percent" -gt 70 ]; then
            print_status "INFO" "Умеренное использование памяти"
        else
            print_status "OK" "Нормальное использование памяти"
        fi
    fi
    
    # Рекомендации
    echo ""
    echo "  💡 Рекомендации:"
    if [ "$mem_usage_percent" -gt 80 ]; then
        echo "    • Рассмотрите увеличение оперативной памяти"
    fi
    if (( $(echo "$load_per_core > 1.0" | bc -l) )); then
        echo "    • Оптимизируйте нагрузку на CPU"
    fi
}

cmd_help() {
    print_header
    echo -e "${CYAN}🖥️  Продвинутый системный монитор - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  monitor  - Мониторинг в реальном времени"
    echo "  quick    - Быстрая проверка системы"
    echo "  report   - Генерация отчета"
    echo "  metrics  - Просмотр метрик"
    echo "  analyze  - Анализ системных показателей"
    echo "  config   - Создание конфигурации"
    echo "  help     - Эта справка"
    echo ""
    echo "Без аргументов: полная проверка системы"
    echo ""
    echo "Примеры:"
    echo "  $0              # Полная проверка"
    echo "  $0 monitor      # Мониторинг в реальном времени"
    echo "  $0 quick        # Быстрая проверка"
    echo "  $0 analyze      # Анализ и рекомендации"
    echo "  $0 metrics      # Просмотр метрик"
}

# Обработка аргументов
case "${1:-}" in
    "monitor") cmd_monitor ;;
    "quick") cmd_quick ;;
    "report") cmd_report ;;
    "metrics") cmd_metrics ;;
    "analyze") cmd_analyze ;;
    "config") cmd_config ;;
    "help"|"--help"|"-h") cmd_help ;;
    *) main ;;
esac
