#!/bin/bash
# 🚨 Улучшенная система мониторинга и оповещений
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
ALERT_DIR="$PROJECT_ROOT/alerts"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$ALERT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Конфигурация оповещений
ALERT_CONFIG="$CONFIG_DIR/alert.conf"
ALERT_LOG="$ALERT_DIR/alert-history.log"
MAIN_LOG="$LOG_DIR/alert-system.log"

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    # Основные системные утилиты
    for cmd in top free df grep awk sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты для расширенных функций
    if [[ " ${ALERT_METHODS[@]} " =~ " email " ]] && ! command -v mail &> /dev/null; then
        echo "⚠️  Утилита 'mail' не найдена. Email оповещения отключены."
        ALERT_METHODS=(${ALERT_METHODS[@]/email})
    fi
    
    if [[ " ${ALERT_METHODS[@]} " =~ " telegram " ]] && ! command -v curl &> /dev/null; then
        echo "⚠️  Утилита 'curl' не найдена. Telegram оповещения отключены."
        ALERT_METHODS=(${ALERT_METHODS[@]/telegram})
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🚨 ==========================================="
    echo "   СИСТЕМА ОПОВЕЩЕНИЙ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📊 $1${NC}"
}

print_alert() {
    echo -e "${RED}🚨 $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Логирование в основной лог
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
}

# Создание конфигурации
create_config() {
    cat > "$ALERT_CONFIG" << 'EOF'
# Конфигурация системы оповещений v2.0

# Пороговые значения для триггеров оповещений

# Загрузка CPU (%)
CPU_CRITICAL=90
CPU_WARNING=80

# Использование памяти (%)
MEMORY_CRITICAL=90
MEMORY_WARNING=80

# Использование диска (%) - можно указать несколько разделов через пробел
DISK_PARTITIONS="/ /home /var"
DISK_CRITICAL=90
DISK_WARNING=80

# Температура CPU (°C)
TEMP_CRITICAL=80
TEMP_WARNING=70

# Сетевая загрузка (KB/s) - суммарная на интерфейсе
NETWORK_INTERFACE="eth0"
NETWORK_CRITICAL=100000  # ~100 MB/s
NETWORK_WARNING=50000    # ~50 MB/s

# Мониторинг сервисов (названия systemd сервисов через пробел)
MONITOR_SERVICES="nginx mysql ssh docker"

# Проверять каждые (секунд)
CHECK_INTERVAL=60

# Методы оповещения
ALERT_METHODS=("log" "console")  # log, console, email, telegram

# Email для оповещений
ALERT_EMAIL=""
SMTP_SERVER="localhost"
SMTP_PORT="25"

# Telegram настройки
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Дополнительные настройки
ENABLE_NETWORK_MONITORING=true
ENABLE_SERVICE_MONITORING=true
LOG_RETENTION_DAYS=30
EOF
    print_success "Конфигурация создана: $ALERT_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$ALERT_CONFIG" ]; then
        source "$ALERT_CONFIG"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        # Значения по умолчанию
        CPU_CRITICAL=90
        CPU_WARNING=80
        MEMORY_CRITICAL=90
        MEMORY_WARNING=80
        DISK_PARTITIONS="/"
        DISK_CRITICAL=90
        DISK_WARNING=80
        TEMP_CRITICAL=80
        TEMP_WARNING=70
        NETWORK_INTERFACE="eth0"
        NETWORK_CRITICAL=100000
        NETWORK_WARNING=50000
        MONITOR_SERVICES=""
        CHECK_INTERVAL=60
        ALERT_METHODS=("log" "console")
        ENABLE_NETWORK_MONITORING=false
        ENABLE_SERVICE_MONITORING=false
    fi
}

# Функции сбора метрик
get_cpu_usage() {
    if ! command -v top &> /dev/null; then
        echo "0"
        return
    fi
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "${cpu_usage%.*}"
}

get_memory_usage() {
    # Используем /proc/meminfo как наиболее надежный метод
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_mem=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$total_mem" ] || [ -z "$available_mem" ] || [ "$total_mem" -eq 0 ]; then
        echo "0"
        return
    fi
    
    local used_mem=$((total_mem - available_mem))
    local usage_percent=$((used_mem * 100 / total_mem))
    echo "$usage_percent"
}

get_disk_usage() {
    local partition=$1
    if [ -z "$partition" ]; then
        partition="/"
    fi
    
    if ! df "$partition" &> /dev/null; then
        echo "N/A"
        return
    fi
    
    local disk_usage=$(df "$partition" | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$disk_usage"
}

get_temperature() {
    local temp_files=(
        "/sys/class/thermal/thermal_zone0/temp"
        "/sys/class/hwmon/hwmon0/temp1_input"
        "/sys/class/hwmon/hwmon1/temp1_input"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [ -f "$temp_file" ]; then
            local temp=$(cat "$temp_file")
            # Если значение больше 1000, значит в миллиградусах
            if [ "$temp" -gt 1000 ]; then
                temp=$((temp / 1000))
            fi
            echo "$temp"
            return
        fi
    done
    echo "N/A"
}

get_network_usage() {
    local interface=$1
    if [ -z "$interface" ] || [ ! -d "/sys/class/net/$interface" ]; then
        echo "N/A"
        return
    fi
    
    # Получаем статистику сети
    local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
    local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
    
    # Ждем секунду для расчета скорости
    sleep 1
    
    local rx_bytes_new=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
    local tx_bytes_new=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
    
    local rx_speed=$(( (rx_bytes_new - rx_bytes) / 1024 ))
    local tx_speed=$(( (tx_bytes_new - tx_bytes) / 1024 ))
    local total_speed=$((rx_speed + tx_speed))
    
    echo "$total_speed"
}

check_service_status() {
    local service=$1
    if ! command -v systemctl &> /dev/null; then
        echo "unknown"
        return
    fi
    
    if systemctl is-active --quiet "$service"; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Методы оповещений
send_alert() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] [$level] $message"
    
    # Логирование всегда
    echo "$full_message" >> "$ALERT_LOG"
    log_message "$level" "$message"
    
    # Console оповещения
    if [[ " ${ALERT_METHODS[@]} " =~ " console " ]]; then
        case $level in
            "CRITICAL")
                print_alert "$message"
                ;;
            "WARNING")
                print_warning "$message"
                ;;
            *)
                print_info "$message"
                ;;
        esac
    fi
    
    # Email оповещения
    if [[ " ${ALERT_METHODS[@]} " =~ " email " ]] && [ -n "$ALERT_EMAIL" ]; then
        send_email_alert "$level" "$message" &
    fi
    
    # Telegram оповещения
    if [[ " ${ALERT_METHODS[@]} " =~ " telegram " ]] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        send_telegram_alert "$level" "$message" &
    fi
}

send_email_alert() {
    local level=$1
    local message=$2
    local subject="🚨 Системное оповещение: $level"
    local body="Время: $(date)\nУровень: $level\nСообщение: $message\n\nСистема: $(hostname)"
    
    echo -e "$body" | mail -s "$subject" -r "alert-system@$(hostname)" "$ALERT_EMAIL" 2>/dev/null || \
    log_message "ERROR" "Не удалось отправить email оповещение"
}

send_telegram_alert() {
    local level=$1
    local message=$2
    local text="*🚨 Системное оповещение*\n*Уровень:* $level\n*Время:* $(date)\n*Сообщение:* $message\n*Система:* $(hostname)"
    
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    local payload="{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"${text}\", \"parse_mode\": \"Markdown\"}"
    
    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" > /dev/null || \
    log_message "ERROR" "Не удалось отправить Telegram оповещение"
}

# Проверка метрик
check_metrics() {
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local temp=$(get_temperature)
    
    local has_alerts=0
    
    # Проверка CPU
    if [ "$cpu_usage" -ge "$CPU_CRITICAL" ] 2>/dev/null; then
        send_alert "CRITICAL" "Высокая загрузка CPU: ${cpu_usage}% (порог: ${CPU_CRITICAL}%)"
        has_alerts=1
    elif [ "$cpu_usage" -ge "$CPU_WARNING" ] 2>/dev/null; then
        send_alert "WARNING" "Загрузка CPU повышена: ${cpu_usage}% (порог: ${CPU_WARNING}%)"
        has_alerts=1
    fi
    
    # Проверка памяти
    if [ "$mem_usage" -ge "$MEMORY_CRITICAL" ] 2>/dev/null; then
        send_alert "CRITICAL" "Высокое использование памяти: ${mem_usage}% (порог: ${MEMORY_CRITICAL}%)"
        has_alerts=1
    elif [ "$mem_usage" -ge "$MEMORY_WARNING" ] 2>/dev/null; then
        send_alert "WARNING" "Использование памяти повышено: ${mem_usage}% (порог: ${MEMORY_WARNING}%)"
        has_alerts=1
    fi
    
    # Проверка дисков
    for partition in $DISK_PARTITIONS; do
        local disk_usage=$(get_disk_usage "$partition")
        if [ "$disk_usage" != "N/A" ]; then
            if [ "$disk_usage" -ge "$DISK_CRITICAL" ] 2>/dev/null; then
                send_alert "CRITICAL" "Высокое использование диска ${partition}: ${disk_usage}% (порог: ${DISK_CRITICAL}%)"
                has_alerts=1
            elif [ "$disk_usage" -ge "$DISK_WARNING" ] 2>/dev/null; then
                send_alert "WARNING" "Использование диска ${partition} повышено: ${disk_usage}% (порог: ${DISK_WARNING}%)"
                has_alerts=1
            fi
        fi
    done
    
    # Проверка температуры
    if [ "$temp" != "N/A" ] && [ "$temp" -ge "$TEMP_CRITICAL" ] 2>/dev/null; then
        send_alert "CRITICAL" "Высокая температура CPU: ${temp}°C (порог: ${TEMP_CRITICAL}°C)"
        has_alerts=1
    elif [ "$temp" != "N/A" ] && [ "$temp" -ge "$TEMP_WARNING" ] 2>/dev/null; then
        send_alert "WARNING" "Температура CPU повышена: ${temp}°C (порог: ${TEMP_WARNING}°C)"
        has_alerts=1
    fi
    
    # Проверка сети
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        local network_usage=$(get_network_usage "$NETWORK_INTERFACE")
        if [ "$network_usage" != "N/A" ]; then
            if [ "$network_usage" -ge "$NETWORK_CRITICAL" ] 2>/dev/null; then
                send_alert "CRITICAL" "Высокая сетевая нагрузка на ${NETWORK_INTERFACE}: ${network_usage} KB/s (порог: ${NETWORK_CRITICAL} KB/s)"
                has_alerts=1
            elif [ "$network_usage" -ge "$NETWORK_WARNING" ] 2>/dev/null; then
                send_alert "WARNING" "Сетевая нагрузка повышена на ${NETWORK_INTERFACE}: ${network_usage} KB/s (порог: ${NETWORK_WARNING} KB/s)"
                has_alerts=1
            fi
        fi
    fi
    
    # Проверка сервисов
    if [ "$ENABLE_SERVICE_MONITORING" = "true" ] && [ -n "$MONITOR_SERVICES" ]; then
        for service in $MONITOR_SERVICES; do
            local status=$(check_service_status "$service")
            if [ "$status" = "inactive" ]; then
                send_alert "CRITICAL" "Сервис $service не запущен"
                has_alerts=1
            fi
        done
    fi
    
    if [ $has_alerts -eq 0 ]; then
        echo "  ✅ Все метрики в норме"
    fi
    
    return $has_alerts
}

# Режим мониторинга
monitor_mode() {
    if ! check_dependencies; then
        print_alert "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_header
    echo "  🔍 Начало мониторинга системы..."
    echo "  ⏰ Интервал проверки: ${CHECK_INTERVAL} секунд"
    echo "  📊 Отслеживаемые метрики:"
    echo "    💻 CPU: > ${CPU_WARNING}% (предупреждение), > ${CPU_CRITICAL}% (критично)"
    echo "    🧠 Память: > ${MEMORY_WARNING}% (предупреждение), > ${MEMORY_CRITICAL}% (критично)"
    echo "    💾 Диски: ${DISK_PARTITIONS}"
    echo "    🌡️  Температура: > ${TEMP_WARNING}°C (предупреждение), > ${TEMP_CRITICAL}°C (критично)"
    
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        echo "    🌐 Сеть (${NETWORK_INTERFACE}): > ${NETWORK_WARNING} KB/s (предупреждение), > ${NETWORK_CRITICAL} KB/s (критично)"
    fi
    
    if [ "$ENABLE_SERVICE_MONITORING" = "true" ] && [ -n "$MONITOR_SERVICES" ]; then
        echo "    🔧 Сервисы: ${MONITOR_SERVICES}"
    fi
    
    echo "  📨 Методы оповещения: ${ALERT_METHODS[*]}"
    echo ""
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        echo "======= Проверка #$counter ($(date '+%H:%M:%S')) ======="
        
        # Показываем текущие значения
        show_current_metrics
        
        echo ""
        echo "  🔍 Результаты проверки:"
        check_metrics
        echo "======================================"
        echo ""
        sleep "$CHECK_INTERVAL"
    done
}

# Показать текущие метрики
show_current_metrics() {
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local temp=$(get_temperature)
    
    echo "  📊 Текущие значения:"
    echo "    💻 CPU: ${cpu_usage}%"
    echo "    🧠 Память: ${mem_usage}%"
    
    for partition in $DISK_PARTITIONS; do
        local disk_usage=$(get_disk_usage "$partition")
        echo "    💾 Диск $partition: ${disk_usage}%"
    done
    
    echo "    🌡️  Температура: ${temp}°C"
    
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        local network_usage=$(get_network_usage "$NETWORK_INTERFACE")
        echo "    🌐 Сеть ${NETWORK_INTERFACE}: ${network_usage} KB/s"
    fi
    
    if [ "$ENABLE_SERVICE_MONITORING" = "true" ] && [ -n "$MONITOR_SERVICES" ]; then
        echo "    🔧 Статус сервисов:"
        for service in $MONITOR_SERVICES; do
            local status=$(check_service_status "$service")
            local status_icon="✅"
            if [ "$status" = "inactive" ]; then
                status_icon="❌"
            elif [ "$status" = "unknown" ]; then
                status_icon="⚠️ "
            fi
            echo "      $status_icon $service: $status"
        done
    fi
}

# Просмотр истории оповещений
show_history() {
    print_section "ИСТОРИЯ ОПОВЕЩЕНИЙ"
    
    if [ -f "$ALERT_LOG" ]; then
        if [ -s "$ALERT_LOG" ]; then
            tail -20 "$ALERT_LOG"
            echo ""
            echo "📁 Полный лог: $ALERT_LOG"
        else
            echo "  ℹ️  Оповещений не было"
        fi
    else
        echo "  ℹ️  Файл лога не существует"
    fi
}

# Статус системы
show_status() {
    print_section "ТЕКУЩИЙ СТАТУС СИСТЕМЫ"
    show_current_metrics
}

# Тест всех функций
test_all() {
    print_header
    echo "  🧪 ТЕСТИРОВАНИЕ ВСЕХ ФУНКЦИЙ"
    echo ""
    
    echo "=== Тест метрик ==="
    echo "CPU: $(get_cpu_usage)%"
    echo "Память: $(get_memory_usage)%"
    echo "Температура: $(get_temperature)°C"
    
    for partition in $DISK_PARTITIONS; do
        echo "Диск $partition: $(get_disk_usage "$partition")%"
    done
    
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        echo "Сеть: $(get_network_usage "$NETWORK_INTERFACE") KB/s"
    fi
    
    echo ""
    echo "=== Тест оповещений ==="
    send_alert "INFO" "Тестовое информационное сообщение"
    send_alert "WARNING" "Тестовое предупреждение"
    send_alert "CRITICAL" "Тестовое критическое сообщение"
    
    echo ""
    echo "=== Проверка сервисов ==="
    if [ "$ENABLE_SERVICE_MONITORING" = "true" ] && [ -n "$MONITOR_SERVICES" ]; then
        for service in $MONITOR_SERVICES; do
            echo "$service: $(check_service_status "$service")"
        done
    fi
    
    print_success "Тестирование завершено"
}

# Очистка старых логов
clean_logs() {
    local retention_days=${LOG_RETENTION_DAYS:-30}
    local cutoff_date=$(date -d "$retention_days days ago" +%Y-%m-%d)
    
    print_section "ОЧИСТКА ЛОГОВ"
    
    if [ -f "$ALERT_LOG" ]; then
        local temp_file=$(mktemp)
        while IFS= read -r line; do
            local log_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
            if [[ "$log_date" > "$cutoff_date" ]] || [[ "$log_date" == "$cutoff_date" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$ALERT_LOG"
        
        mv "$temp_file" "$ALERT_LOG"
        print_success "Логи старше $retention_days дней очищены"
    else
        print_info "Файл лога не существует"
    fi
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "monitor")
            monitor_mode
            ;;
        "status")
            print_header
            show_status
            ;;
        "history")
            print_header
            show_history
            ;;
        "config")
            create_config
            ;;
        "test")
            test_all
            ;;
        "clean")
            clean_logs
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА]"
            echo ""
            echo "Команды:"
            echo "  monitor  - Непрерывный мониторинг системы"
            echo "  status   - Текущий статус системы"
            echo "  history  - История оповещений"
            echo "  config   - Создать конфигурационный файл"
            echo "  test     - Тестирование всех функций"
            echo "  clean    - Очистка старых логов"
            echo "  help     - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 monitor    # Запуск мониторинга"
            echo "  $0 status     # Проверка текущего статуса"
            echo "  $0 test       # Тестирование всех функций"
            echo "  $0 clean      # Очистка старых логов"
            ;;
        *)
            print_alert "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            exit 1
            ;;
    esac
}

main "$@"
