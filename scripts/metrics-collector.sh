#!/bin/bash
# 📈 Сборщик системных метрик для мониторинга производительности
# Автор: g1if

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
METRICS_DIR="$PROJECT_ROOT/metrics"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$METRICS_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Конфигурация по умолчанию
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=85

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "📈 ==========================================="
    echo "   СБОРЩИК СИСТЕМНЫХ МЕТРИК v1.2"
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

show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  overview   - Краткий обзор метрик"
    echo "  detailed   - Подробный отчет"
    echo "  monitor    - Режим мониторинга (как top)"
    echo "  export     - Экспорт метрик в CSV"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 overview"
    echo "  $0 detailed"
    echo "  $0 monitor"
}

# Функции сбора метрик
get_cpu_usage() {
    # Более надежный способ получения загрузки CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "${cpu_usage%.*}"  # Возвращаем целое число
}

get_memory_usage() {
    # Используем free для получения информации о памяти
    local memory_info=$(free 2>/dev/null | grep Mem)
    if [ -z "$memory_info" ]; then
        echo "0"
        return
    fi
    
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local available_mem=$(echo $memory_info | awk '{print $7}')
    
    # Проверяем, что total_mem не пустой и является числом
    if [ -z "$total_mem" ] || ! [[ "$total_mem" =~ ^[0-9]+$ ]] || [ "$total_mem" -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Правильный расчет использования памяти
    if [ -n "$available_mem" ] && [[ "$available_mem" =~ ^[0-9]+$ ]]; then
        local used_mem=$((total_mem - available_mem))
        local usage_percent=$((used_mem * 100 / total_mem))
        echo "$usage_percent"
    else
        # Альтернативный расчет если available недоступен
        local used_mem=$(echo $memory_info | awk '{print $3}')
        local usage_percent=$((used_mem * 100 / total_mem))
        echo "$usage_percent"
    fi
}

get_disk_usage() {
    # Используем df для получения использования корневого раздела
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$disk_usage"
}

get_network_usage() {
    # Получаем статистику сети для основного интерфейса
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$interface" ]; then
        echo "0 0"
        return
    fi
    
    # Читаем текущие значения
    local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo "0")
    local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo "0")
    
    echo "$rx_bytes $tx_bytes"
}

get_temperature() {
    # Пытаемся получить температуру с различных датчиков
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
        echo "$temp"
    elif command -v sensors >/dev/null 2>&1; then
        # Берем только целую часть температуры
        local temp=$(sensors | grep -oP 'Core 0:\s+\+\K\d+\.\d' | head -1 | cut -d. -f1)
        echo "$temp"
    else
        echo "N/A"
    fi
}

get_uptime() {
    # Время работы системы
    local uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local days=$(( ${uptime_seconds%.*} / 86400 ))
    local hours=$(( (${uptime_seconds%.*} % 86400) / 3600 ))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h"
    else
        echo "${hours}h"
    fi
}

get_load_average() {
    # Средняя нагрузка системы
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

# Функции отчетов
overview_report() {
    print_section "ОБЗОР СИСТЕМНЫХ МЕТРИК"
    
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local temp=$(get_temperature)
    local uptime=$(get_uptime)
    local load_avg=$(get_load_average)
    
    echo "  🖥️  Система:"
    echo "    ⏱️  Время работы: $uptime"
    echo "    📊 Нагрузка: $load_avg"
    echo ""
    
    echo "  📈 Метрики производительности:"
    echo "    💻 CPU: ${cpu_usage}%"
    if [ "$cpu_usage" -gt "$THRESHOLD_CPU" ] 2>/dev/null; then
        print_warning "    ⚠️  Высокая загрузка CPU!"
    fi
    
    echo "    🧠 Память: ${mem_usage}%"
    if [ "$mem_usage" -gt "$THRESHOLD_MEM" ] 2>/dev/null; then
        print_warning "    ⚠️  Высокое использование памяти!"
    fi
    
    echo "    💾 Диск: ${disk_usage}%"
    if [ "$disk_usage" -gt "$THRESHOLD_DISK" ] 2>/dev/null; then
        print_warning "    ⚠️  Высокое использование диска!"
    fi
    
    if [ "$temp" != "N/A" ]; then
        echo "    🌡️  Температура: ${temp}°C"
    fi
    
    # Сетевая активность
    local network_usage=($(get_network_usage))
    local rx_mb=$(( ${network_usage[0]} / 1024 / 1024 ))
    local tx_mb=$(( ${network_usage[1]} / 1024 / 1024 ))
    
    echo ""
    echo "  🌐 Сетевая активность:"
    echo "    📥 Входящий: ${rx_mb} MB"
    echo "    📤 Исходящий: ${tx_mb} MB"
}

detailed_report() {
    print_section "ПОДРОБНЫЙ ОТЧЕТ О МЕТРИКАХ"
    
    # CPU подробно
    echo "  💻 ПРОЦЕССОР:"
    if command -v lscpu >/dev/null 2>&1; then
        local cpu_model=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')
        local cpu_cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
        echo "    Модель: $cpu_model"
        echo "    Ядер: $cpu_cores"
    else
        echo "    Ядер: $(nproc)"
    fi
    local cpu_usage=$(get_cpu_usage)
    echo "    Загрузка: ${cpu_usage}%"
    
    # Память подробно
    echo ""
    echo "  🧠 ПАМЯТЬ:"
    free -h | head -2 | while read line; do
        echo "    $line"
    done
    
    # Диски подробно
    echo ""
    echo "  💾 ДИСКИ:"
    df -h | head -10 | while read line; do
        echo "    $line"
    done
    
    # Сеть подробно
    echo ""
    echo "  📡 СЕТЬ:"
    ip -br addr show | head -10 | while read line; do
        echo "    $line"
    done
    
    # Процессы
    echo ""
    echo "  🔄 ПРОЦЕССЫ (топ-5 по CPU):"
    ps aux --sort=-%cpu | head -6 | while read line; do
        echo "    $line"
    done
}

monitor_mode() {
    print_section "РЕЖИМ МОНИТОРИНГА"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Обновление каждые 2 секунды..."
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "  🔄 Цикл мониторинга: $counter"
        echo "  ==================================="
        overview_report
        echo ""
        echo "  ⌛ Следующее обновление через 2 секунды..."
        sleep 2
    done
}

export_metrics() {
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local csv_file="$METRICS_DIR/metrics_$timestamp.csv"
    
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local temp=$(get_temperature)
    local network_usage=($(get_network_usage))
    
    # Создаем CSV файл с заголовком
    echo "timestamp,cpu_usage,memory_usage,disk_usage,temperature,rx_bytes,tx_bytes" > "$csv_file"
    echo "$(date +%Y-%m-%d\ %H:%M:%S),$cpu_usage,$mem_usage,$disk_usage,$temp,${network_usage[0]},${network_usage[1]}" >> "$csv_file"
    
    print_success "Метрики экспортированы в: $csv_file"
    echo "  📊 Данные: CPU=${cpu_usage}%, RAM=${mem_usage}%, Disk=${disk_usage}%"
}

main() {
    case "${1:-}" in
        "overview")
            print_header
            overview_report
            ;;
        "detailed")
            print_header
            detailed_report
            ;;
        "monitor")
            print_header
            monitor_mode
            ;;
        "export")
            print_header
            export_metrics
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

# Проверяем наличие необходимых утилит
check_dependencies() {
    local deps=("free" "df" "ip")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            print_warning "Утилита $dep не установлена. Некоторые функции могут работать некорректно."
        fi
    done
}

check_dependencies
main "$@"
