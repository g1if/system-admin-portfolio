#!/bin/bash
# 🚨 Система оповещений на основе метрик
# Автор: g1if

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
NC='\033[0m'

# Конфигурация оповещений
ALERT_CONFIG="$CONFIG_DIR/alert.conf"
ALERT_LOG="$ALERT_DIR/alert-history.log"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🚨 ==========================================="
    echo "   СИСТЕМА ОПОВЕЩЕНИЙ v1.2"
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

# Создание конфигурации
create_config() {
    cat > "$ALERT_CONFIG" << 'EOF'
# Конфигурация системы оповещений
# Пороговые значения для триггеров оповещений

# Загрузка CPU (%)
CPU_CRITICAL=90
CPU_WARNING=80

# Использование памяти (%)
MEMORY_CRITICAL=90
MEMORY_WARNING=80

# Использование диска (%)
DISK_CRITICAL=90
DISK_WARNING=80

# Температура CPU (°C)
TEMP_CRITICAL=80
TEMP_WARNING=70

# Проверять каждые (секунд)
CHECK_INTERVAL=60

# Методы оповещения
ALERT_METHODS=("log" "console")  # log, console, email, telegram

# Email для оповещений (если используется)
ALERT_EMAIL=""

# Telegram настройки (если используется)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
    print_success "Конфигурация создана: $ALERT_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$ALERT_CONFIG" ]; then
        source "$ALERT_CONFIG"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        # Значения по умолчанию
        CPU_CRITICAL=90
        CPU_WARNING=80
        MEMORY_CRITICAL=90
        MEMORY_WARNING=80
        DISK_CRITICAL=90
        DISK_WARNING=80
        TEMP_CRITICAL=80
        TEMP_WARNING=70
        CHECK_INTERVAL=5
        ALERT_METHODS=("log" "console")
    fi
}

# Функции сбора метрик (аналогичные metrics-collector)
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "${cpu_usage%.*}"
}

get_memory_usage() {
    # Используем free для получения информации о памяти (работает с русской локалью)
    local memory_info=$(free | grep -E "(Память:|Mem:)" | head -1)
    
    if [ -z "$memory_info" ]; then
        # Пробуем английскую локаль
        memory_info=$(free | grep "Mem:" | head -1)
    fi
    
    if [ -z "$memory_info" ]; then
        echo "0"
        return
    fi
    
    # Извлекаем числа из строки (вне зависимости от локали)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    
    # Проверяем, что значения валидны
    if [ -z "$total_mem" ] || [ -z "$used_mem" ] || [ "$total_mem" -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Правильный расчет использования памяти
    local usage_percent=$((used_mem * 100 / total_mem))
    echo "$usage_percent"
}

# Альтернативная функция через /proc/meminfo (более надежная)
get_memory_usage_alt() {
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

# Отладочная информация о памяти
debug_memory() {
    echo "=== ОТЛАДКА ПАМЯТИ ==="
    echo "Сырые данные free:"
    free
    echo ""
    echo "Сырые данные free -m:"
    free -m
    echo ""
    echo "Сырые данные free -h:"
    free -h
    echo ""
    
    # Тестируем обе функции
    echo "=== РАСЧЕТ ИСПОЛЬЗОВАНИЯ ПАМЯТИ ==="
    local memory_info=$(free | grep -E "(Память:|Mem:)" | head -1)
    echo "Найдена строка: $memory_info"
    
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    
    echo "Total: $total_mem"
    echo "Used: $used_mem"
    
    if [ -n "$total_mem" ] && [ -n "$used_mem" ] && [ "$total_mem" -ne 0 ]; then
        echo "Расчет: ($used_mem * 100 / $total_mem) = $((used_mem * 100 / total_mem))%"
    else
        echo "Ошибка: не удалось извлечь данные"
    fi
    
    echo ""
    echo "=== АЛЬТЕРНАТИВНЫЙ РАСЧЕТ (/proc/meminfo) ==="
    local total_mem_alt=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_mem_alt=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    echo "MemTotal: $total_mem_alt KB"
    echo "MemAvailable: $available_mem_alt KB"
    
    if [ -n "$total_mem_alt" ] && [ -n "$available_mem_alt" ] && [ "$total_mem_alt" -ne 0 ]; then
        local used_mem_alt=$((total_mem_alt - available_mem_alt))
        echo "Used (calculated): $used_mem_alt KB"
        echo "Расчет: ($used_mem_alt * 100 / $total_mem_alt) = $((used_mem_alt * 100 / total_mem_alt))%"
    fi
    
    echo ""
    echo "=== РЕЗУЛЬТАТЫ ФУНКЦИЙ ==="
    echo "get_memory_usage: $(get_memory_usage)%"
    echo "get_memory_usage_alt: $(get_memory_usage_alt)%"
}

get_disk_usage() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$disk_usage"
}

get_temperature() {
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
        echo "$temp"
    else
        echo "N/A"
    fi
}

# Логирование оповещений
log_alert() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$ALERT_LOG"
    
    if [[ " ${ALERT_METHODS[@]} " =~ " console " ]]; then
        case $level in
            "CRITICAL")
                print_alert "$message"
                ;;
            "WARNING")
                print_warning "$message"
                ;;
            *)
                echo "ℹ️  $message"
                ;;
        esac
    fi
}

# Проверка метрик
check_metrics() {
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local temp=$(get_temperature)
    
    local has_alerts=0
    
    # Проверка CPU
    if [ "$cpu_usage" -ge "$CPU_CRITICAL" ] 2>/dev/null; then
        log_alert "CRITICAL" "Высокая загрузка CPU: ${cpu_usage}% (порог: ${CPU_CRITICAL}%)"
        has_alerts=1
    elif [ "$cpu_usage" -ge "$CPU_WARNING" ] 2>/dev/null; then
        log_alert "WARNING" "Загрузка CPU повышена: ${cpu_usage}% (порог: ${CPU_WARNING}%)"
        has_alerts=1
    fi
    
    # Проверка памяти
    if [ "$mem_usage" -ge "$MEMORY_CRITICAL" ] 2>/dev/null; then
        log_alert "CRITICAL" "Высокое использование памяти: ${mem_usage}% (порог: ${MEMORY_CRITICAL}%)"
        has_alerts=1
    elif [ "$mem_usage" -ge "$MEMORY_WARNING" ] 2>/dev/null; then
        log_alert "WARNING" "Использование памяти повышено: ${mem_usage}% (порог: ${MEMORY_WARNING}%)"
        has_alerts=1
    fi
    
    # Проверка диска
    if [ "$disk_usage" -ge "$DISK_CRITICAL" ] 2>/dev/null; then
        log_alert "CRITICAL" "Высокое использование диска: ${disk_usage}% (порог: ${DISK_CRITICAL}%)"
        has_alerts=1
    elif [ "$disk_usage" -ge "$DISK_WARNING" ] 2>/dev/null; then
        log_alert "WARNING" "Использование диска повышено: ${disk_usage}% (порог: ${DISK_WARNING}%)"
        has_alerts=1
    fi
    
    # Проверка температуры
    if [ "$temp" != "N/A" ] && [ "$temp" -ge "$TEMP_CRITICAL" ] 2>/dev/null; then
        log_alert "CRITICAL" "Высокая температура CPU: ${temp}°C (порог: ${TEMP_CRITICAL}°C)"
        has_alerts=1
    elif [ "$temp" != "N/A" ] && [ "$temp" -ge "$TEMP_WARNING" ] 2>/dev/null; then
        log_alert "WARNING" "Температура CPU повышена: ${temp}°C (порог: ${TEMP_WARNING}°C)"
        has_alerts=1
    fi
    
    if [ $has_alerts -eq 0 ]; then
        echo "  ✅ Все метрики в норме"
    fi
}

# Режим мониторинга
monitor_mode() {
    print_header
    echo "  🔍 Начало мониторинга системы..."
    echo "  ⏰ Интервал проверки: ${CHECK_INTERVAL} секунд"
    echo "  📊 Отслеживаемые метрики:"
    echo "    💻 CPU: > ${CPU_WARNING}% (предупреждение), > ${CPU_CRITICAL}% (критично)"
    echo "    🧠 Память: > ${MEMORY_WARNING}% (предупреждение), > ${MEMORY_CRITICAL}% (критично)"
    echo "    💾 Диск: > ${DISK_WARNING}% (предупреждение), > ${DISK_CRITICAL}% (критично)"
    echo "    🌡️  Температура: > ${TEMP_WARNING}°C (предупреждение), > ${TEMP_CRITICAL}°C (критично)"
    echo ""
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        echo "======= Проверка #$counter ($(date '+%H:%M:%S')) ======="
        # Показываем текущие значения
        local cpu_usage=$(get_cpu_usage)
        local mem_usage=$(get_memory_usage)
        local disk_usage=$(get_disk_usage)
        local temp=$(get_temperature)
        echo "  📊 Текущие значения:"
        echo "    💻 CPU: ${cpu_usage}%"
        echo "    🧠 Память: ${mem_usage}%"
        echo "    💾 Диск: ${disk_usage}%"
        echo "    🌡️  Температура: ${temp}°C"
        echo ""
        echo "  🔍 Результаты проверки:"
        check_metrics
        echo "======================================"
        echo ""
        sleep "$CHECK_INTERVAL"
    done
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
    
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local temp=$(get_temperature)
    
    echo -n "  💻 CPU: ${cpu_usage}% - "
    if [ "$cpu_usage" -ge "$CPU_CRITICAL" ] 2>/dev/null; then
        print_alert "КРИТИЧЕСКИЙ УРОВЕНЬ"
    elif [ "$cpu_usage" -ge "$CPU_WARNING" ] 2>/dev/null; then
        print_warning "ПРЕДУПРЕЖДЕНИЕ"
    else
        print_success "НОРМА"
    fi
    
    echo -n "  🧠 Память: ${mem_usage}% - "
    if [ "$mem_usage" -ge "$MEMORY_CRITICAL" ] 2>/dev/null; then
        print_alert "КРИТИЧЕСКИЙ УРОВЕНЬ"
    elif [ "$mem_usage" -ge "$MEMORY_WARNING" ] 2>/dev/null; then
        print_warning "ПРЕДУПРЕЖДЕНИЕ"
    else
        print_success "НОРМА"
    fi
    
    echo -n "  💾 Диск: ${disk_usage}% - "
    if [ "$disk_usage" -ge "$DISK_CRITICAL" ] 2>/dev/null; then
        print_alert "КРИТИЧЕСКИЙ УРОВЕНЬ"
    elif [ "$disk_usage" -ge "$DISK_WARNING" ] 2>/dev/null; then
        print_warning "ПРЕДУПРЕЖДЕНИЕ"
    else
        print_success "НОРМА"
    fi
    
    if [ "$temp" != "N/A" ]; then
        echo -n "  🌡️  Температура: ${temp}°C - "
        if [ "$temp" -ge "$TEMP_CRITICAL" ] 2>/dev/null; then
            print_alert "КРИТИЧЕСКИЙ УРОВЕНЬ"
        elif [ "$temp" -ge "$TEMP_WARNING" ] 2>/dev/null; then
            print_warning "ПРЕДУПРЕЖДЕНИЕ"
        else
            print_success "НОРМА"
        fi
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
            print_header
            echo "  🧪 ТЕСТОВАЯ ПРОВЕРКА МЕТРИК"
            echo ""
            check_metrics
            ;;
	"debug-memory")
            debug_memory
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
            echo "  test     - Тестовая проверка метрик"
            echo "  help     - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 monitor    # Запуск мониторинга"
            echo "  $0 status     # Проверка текущего статуса"
            echo "  $0 history    # Просмотр истории оповещений"
            ;;
        *)
            print_alert "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            exit 1
            ;;
    esac
}

main "$@"
