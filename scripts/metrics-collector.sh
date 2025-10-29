#!/bin/bash
# 📈 Продвинутый сборщик системных метрик с аналитикой и визуализацией
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
METRICS_DIR="$PROJECT_ROOT/metrics"
CACHE_DIR="$PROJECT_ROOT/cache"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$METRICS_DIR" "$CACHE_DIR"

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
CONFIG_FILE="$CONFIG_DIR/metrics.conf"
MAIN_LOG="$LOG_DIR/metrics-collector.log"
CACHE_FILE="$CACHE_DIR/metrics-cache.db"
HISTORY_FILE="$METRICS_DIR/metrics-history.csv"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "📈 ==========================================="
    echo "   ПРОДВИНУТЫЙ СБОРЩИК МЕТРИК v2.0"
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
# Конфигурация сборщика метрик v2.0

# Основные настройки
COLLECTION_INTERVAL=5
ENABLE_HISTORY=true
HISTORY_RETENTION_DAYS=30
COMPRESS_OLD_DATA=true

# Пороговые значения для оповещений
THRESHOLD_CPU_CRITICAL=90
THRESHOLD_CPU_WARNING=80
THRESHOLD_MEMORY_CRITICAL=90
THRESHOLD_MEMORY_WARNING=80
THRESHOLD_DISK_CRITICAL=90
THRESHOLD_DISK_WARNING=85
THRESHOLD_TEMP_CRITICAL=80
THRESHOLD_TEMP_WARNING=70
THRESHOLD_LOAD_CRITICAL=4.0
THRESHOLD_LOAD_WARNING=2.0

# Мониторинг дисков (разделы через пробел)
MONITOR_DISKS="/ /home /var /opt"

# Сетевые интерфейсы для мониторинга
NETWORK_INTERFACES="eth0 enp0s3 wlan0"

# Дополнительные метрики
ENABLE_DOCKER_METRICS=false
ENABLE_PROCESS_METRICS=true
ENABLE_IO_METRICS=true
ENABLE_NETWORK_DETAILS=true

# Настройки экспорта
EXPORT_FORMATS=("csv" "json")
EXPORT_AUTO=true
EXPORT_INTERVAL=300  # секунды

# Настройки мониторинга
MONITOR_REFRESH_RATE=2
SHOW_TRENDS=true
COLORIZE_OUTPUT=true

# Настройки производительности
ENABLE_CACHING=true
CACHE_TTL=10
MAX_HISTORY_SIZE=1000000
EOF
    print_success "Конфигурация создана: $CONFIG_FILE"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        # Значения по умолчанию
        COLLECTION_INTERVAL=5
        THRESHOLD_CPU_CRITICAL=90
        THRESHOLD_CPU_WARNING=80
        THRESHOLD_MEMORY_CRITICAL=90
        THRESHOLD_MEMORY_WARNING=80
        THRESHOLD_DISK_CRITICAL=90
        THRESHOLD_DISK_WARNING=85
        MONITOR_DISKS="/"
        NETWORK_INTERFACES="eth0"
        ENABLE_HISTORY=true
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in top free df awk grep sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты
    if [ "$ENABLE_DOCKER_METRICS" = "true" ] && ! command -v docker &> /dev/null; then
        optional_missing+=("docker")
    fi
    
    if ! command -v jq &> /dev/null; then
        optional_missing+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        optional_missing+=("bc")
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
        # Удаляем старые записи с таким же ключом
        grep -v "^$key|" "$CACHE_FILE" 2>/dev/null > "${CACHE_FILE}.tmp" || true
        echo "$key|$value|$expire" >> "${CACHE_FILE}.tmp"
        mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
    fi
}

cache_get() {
    local key=$1
    local current_time=$(date +%s)
    
    if [ ! -f "$CACHE_FILE" ] || [ "$ENABLE_CACHING" != "true" ]; then
        return 1
    fi
    
    while IFS='|' read -r cache_key value expire; do
        if [ "$cache_key" = "$key" ] && [ "$current_time" -lt "$expire" ]; then
            echo "$value"
            return 0
        fi
    done < "$CACHE_FILE"
    
    return 1
}

# Функции сбора метрик
get_cpu_usage() {
    local cache_key="cpu_usage"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    # Используем несколько методов для надежности
    local cpu_usage=0
    
    # Метод 1: через /proc/stat (наиболее точный)
    if [ -f "/proc/stat" ]; then
        local cpu_line=$(grep '^cpu ' /proc/stat)
        local user=$(echo $cpu_line | awk '{print $2}')
        local nice=$(echo $cpu_line | awk '{print $3}')
        local system=$(echo $cpu_line | awk '{print $4}')
        local idle=$(echo $cpu_line | awk '{print $5}')
        local iowait=$(echo $cpu_line | awk '{print $6}')
        
        local total=$((user + nice + system + idle + iowait))
        local used=$((user + nice + system))
        
        if [ "$total" -gt 0 ]; then
            cpu_usage=$((used * 100 / total))
        fi
    fi
    
    # Метод 2: через top (резервный)
    if [ "$cpu_usage" -eq 0 ] && command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        cpu_usage=${cpu_usage%.*}
    fi
    
    cache_set "$cache_key" "$cpu_usage" 2
    echo "$cpu_usage"
}

get_memory_usage() {
    local cache_key="memory_usage"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    # Используем /proc/meminfo как наиболее надежный метод
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_mem=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$total_mem" ] || [ -z "$available_mem" ] || [ "$total_mem" -eq 0 ]; then
        echo "0"
        return
    fi
    
    local used_mem=$((total_mem - available_mem))
    local usage_percent=$((used_mem * 100 / total_mem))
    
    cache_set "$cache_key" "$usage_percent" 2
    echo "$usage_percent"
}

get_disk_usage() {
    local partition=$1
    local cache_key="disk_usage_${partition//\//_}"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    if ! df "$partition" &> /dev/null; then
        echo "N/A"
        return
    fi
    
    local disk_usage=$(df "$partition" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    cache_set "$cache_key" "$disk_usage" 30
    echo "$disk_usage"
}

get_temperature() {
    local cache_key="temperature"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    local temp="N/A"
    
    # Пробуем разные источники температуры
    local temp_files=(
        "/sys/class/thermal/thermal_zone0/temp"
        "/sys/class/hwmon/hwmon0/temp1_input"
        "/sys/class/hwmon/hwmon1/temp1_input"
        "/sys/class/hwmon/hwmon2/temp1_input"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [ -f "$temp_file" ]; then
            local raw_temp=$(cat "$temp_file")
            # Если значение больше 1000, значит в миллиградусах
            if [ "$raw_temp" -gt 1000 ]; then
                temp=$((raw_temp / 1000))
            else
                temp="$raw_temp"
            fi
            break
        fi
    done
    
    # Если не нашли через sysfs, пробуем sensors
    if [ "$temp" = "N/A" ] && command -v sensors &> /dev/null; then
        temp=$(sensors | grep -oP 'Core 0:\s+\+\K\d+\.\d' | head -1 | cut -d. -f1)
        if [ -z "$temp" ]; then
            temp=$(sensors | grep -oP 'Package id 0:\s+\+\K\d+\.\d' | head -1 | cut -d. -f1)
        fi
    fi
    
    cache_set "$cache_key" "$temp" 10
    echo "$temp"
}

get_network_usage() {
    local interface=$1
    local cache_key="network_${interface}"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    if [ -z "$interface" ] || [ ! -d "/sys/class/net/$interface" ]; then
        echo "0 0"
        return
    fi
    
    local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")
    
    cache_set "$cache_key" "$rx_bytes $tx_bytes" 2
    echo "$rx_bytes $tx_bytes"
}

get_load_average() {
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

get_uptime() {
    local uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local days=$(( ${uptime_seconds%.*} / 86400 ))
    local hours=$(( (${uptime_seconds%.*} % 86400) / 3600 ))
    local minutes=$(( (${uptime_seconds%.*} % 3600) / 60 ))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

get_detailed_memory_info() {
    echo "=== ДЕТАЛЬНАЯ ИНФОРМАЦИЯ О ПАМЯТИ ==="
    free -h
    echo ""
    echo "=== /proc/meminfo ==="
    grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree)" /proc/meminfo
}

get_disk_io_stats() {
    if [ "$ENABLE_IO_METRICS" = "true" ] && [ -f "/proc/diskstats" ]; then
        echo "=== СТАТИСТИКА DISK I/O ==="
        # Показываем статистику для основных устройств
        grep -E "(sda|nvme|vda)" /proc/diskstats | head -5
    fi
}

get_process_stats() {
    if [ "$ENABLE_PROCESS_METRICS" = "true" ]; then
        echo "=== СТАТИСТИКА ПРОЦЕССОВ ==="
        echo "👑 Топ-5 процессов по CPU:"
        ps aux --sort=-%cpu | head -6 | awk '{printf "  %-8s %-6s %-4s %s\n", $2, $1, $3, $11}'
        echo ""
        echo "💾 Топ-5 процессов по памяти:"
        ps aux --sort=-%mem | head -6 | awk '{printf "  %-8s %-6s %-4s %s\n", $2, $1, $4, $11}'
    fi
}

get_docker_stats() {
    if [ "$ENABLE_DOCKER_METRICS" = "true" ] && command -v docker &> /dev/null; then
        echo "=== DOCKER СТАТИСТИКА ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker не доступен"
    fi
}

# Анализ и тренды
analyze_trends() {
    local current_value=$1
    local previous_value=$2
    local metric_name=$3
    
    if [ -z "$previous_value" ] || [ "$previous_value" = "0" ]; then
        return
    fi
    
    local change=$((current_value - previous_value))
    local change_percent=$((change * 100 / previous_value))
    
    if [ ${change_percent#-} -gt 10 ]; then  # Изменение больше 10%
        if [ $change -gt 0 ]; then
            echo "  📈 $metric_name: +${change_percent}% за период"
        else
            echo "  📉 $metric_name: ${change_percent}% за период"
        fi
    fi
}

# Функции отчетов
overview_report() {
    print_section "ОБЗОР СИСТЕМНЫХ МЕТРИК"
    
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local temp=$(get_temperature)
    local uptime=$(get_uptime)
    local load_avg=$(get_load_average)
    
    echo "  🖥️  Система:"
    echo "    ⏱️  Время работы: $uptime"
    echo "    📊 Нагрузка: $load_avg"
    
    # Анализ нагрузки
    local load1=$(echo $load_avg | awk '{print $1}')
    if (( $(echo "$load1 > $THRESHOLD_LOAD_CRITICAL" | bc -l 2>/dev/null || echo "0") )); then
        print_error "    🚨 Критическая нагрузка системы!"
    elif (( $(echo "$load1 > $THRESHOLD_LOAD_WARNING" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "    ⚠️  Высокая нагрузка системы!"
    fi
    
    echo ""
    echo "  📈 Основные метрики:"
    
    # CPU
    echo -n "    💻 CPU: ${cpu_usage}%"
    if [ "$cpu_usage" -ge "$THRESHOLD_CPU_CRITICAL" ] 2>/dev/null; then
        print_error " 🚨 КРИТИЧЕСКИЙ"
    elif [ "$cpu_usage" -ge "$THRESHOLD_CPU_WARNING" ] 2>/dev/null; then
        print_warning " ⚠️  ВЫСОКИЙ"
    else
        print_success " ✅ НОРМА"
    fi
    
    # Память
    echo -n "    🧠 Память: ${mem_usage}%"
    if [ "$mem_usage" -ge "$THRESHOLD_MEMORY_CRITICAL" ] 2>/dev/null; then
        print_error " 🚨 КРИТИЧЕСКИЙ"
    elif [ "$mem_usage" -ge "$THRESHOLD_MEMORY_WARNING" ] 2>/dev/null; then
        print_warning " ⚠️  ВЫСОКИЙ"
    else
        print_success " ✅ НОРМА"
    fi
    
    # Диски
    echo "    💾 Диски:"
    for disk in $MONITOR_DISKS; do
        local disk_usage=$(get_disk_usage "$disk")
        if [ "$disk_usage" != "N/A" ]; then
            echo -n "      $disk: ${disk_usage}%"
            if [ "$disk_usage" -ge "$THRESHOLD_DISK_CRITICAL" ] 2>/dev/null; then
                print_error " 🚨 КРИТИЧЕСКИЙ"
            elif [ "$disk_usage" -ge "$THRESHOLD_DISK_WARNING" ] 2>/dev/null; then
                print_warning " ⚠️  ВЫСОКИЙ"
            else
                print_success " ✅ НОРМА"
            fi
        fi
    done
    
    # Температура
    if [ "$temp" != "N/A" ]; then
        echo -n "    🌡️  Температура: ${temp}°C"
        if [ "$temp" -ge "$THRESHOLD_TEMP_CRITICAL" ] 2>/dev/null; then
            print_error " 🚨 КРИТИЧЕСКИЙ"
        elif [ "$temp" -ge "$THRESHOLD_TEMP_WARNING" ] 2>/dev/null; then
            print_warning " ⚠️  ВЫСОКИЙ"
        else
            print_success " ✅ НОРМА"
        fi
    fi
    
    # Сеть
    echo "    🌐 Сеть:"
    for interface in $NETWORK_INTERFACES; do
        local network_data=($(get_network_usage "$interface"))
        local rx_bytes=${network_data[0]}
        local tx_bytes=${network_data[1]}
        
        if [ "$rx_bytes" -gt 0 ] || [ "$tx_bytes" -gt 0 ]; then
            local rx_mb=$((rx_bytes / 1024 / 1024))
            local tx_mb=$((tx_bytes / 1024 / 1024))
            echo "      📡 $interface: 📥 ${rx_mb}MB 📤 ${tx_mb}MB"
        fi
    done
}

detailed_report() {
    print_section "ПОДРОБНЫЙ ОТЧЕТ О МЕТРИКАХ"
    
    # Системная информация
    echo "  🖥️  СИСТЕМНАЯ ИНФОРМАЦИЯ:"
    echo "    Hostname: $(hostname)"
    echo "    OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    echo "    Kernel: $(uname -r)"
    echo "    Architecture: $(uname -m)"
    echo "    Uptime: $(get_uptime)"
    echo ""
    
    # CPU детально
    echo "  💻 ПРОЦЕССОР:"
    if command -v lscpu >/dev/null 2>&1; then
        echo "    Модель: $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')"
        echo "    Ядер: $(nproc)"
        echo "    Тактовая частота: $(lscpu | grep "CPU MHz" | awk '{print $3}') MHz"
    else
        echo "    Ядер: $(nproc)"
    fi
    echo "    Загрузка: $(get_cpu_usage)%"
    echo "    Нагрузка: $(get_load_average)"
    echo ""
    
    # Память детально
    get_detailed_memory_info
    echo ""
    
    # Диски детально
    echo "  💾 ДИСКОВОЕ ПРОСТРАНСТВО:"
    df -h | head -10
    echo ""
    
    # I/O статистика
    get_disk_io_stats
    echo ""
    
    # Процессы
    get_process_stats
    echo ""
    
    # Docker (если включен)
    if [ "$ENABLE_DOCKER_METRICS" = "true" ]; then
        get_docker_stats
        echo ""
    fi
    
    # Сеть детально
    if [ "$ENABLE_NETWORK_DETAILS" = "true" ]; then
        echo "  🌐 СЕТЕВЫЕ ИНТЕРФЕЙСЫ:"
        ip -br addr show | head -10
    fi
}

# Сохранение истории метрик
save_metrics_history() {
    if [ "$ENABLE_HISTORY" != "true" ]; then
        return
    fi
    
    local timestamp=$(date +%Y-%m-%d_%H:%M:%S)
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    
    # Создаем заголовок если файла нет
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "timestamp,cpu_usage,memory_usage" > "$HISTORY_FILE"
    fi
    
    echo "$timestamp,$cpu_usage,$mem_usage" >> "$HISTORY_FILE"
    
    # Очистка старых данных если файл слишком большой
    local file_size=$(stat -f%z "$HISTORY_FILE" 2>/dev/null || stat -c%s "$HISTORY_FILE" 2>/dev/null || echo "0")
    if [ "$file_size" -gt "$MAX_HISTORY_SIZE" ]; then
        tail -n 1000 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
}

# Продвинутый режим мониторинга
monitor_mode() {
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_section "ПРОДВИНУТЫЙ РЕЖИМ МОНИТОРИНГА"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Обновление каждые $MONITOR_REFRESH_RATE секунд..."
    echo "  💾 История метрик: $( [ "$ENABLE_HISTORY" = "true" ] && echo "включена" || echo "выключена" )"
    echo ""
    
    local counter=0
    local previous_cpu=0
    local previous_mem=0
    
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "  🔄 Цикл мониторинга: $counter"
        echo "  ⏰ Время: $(date '+%H:%M:%S')"
        echo "  ==================================="
        
        overview_report
        
        # Показываем тренды если включено
        if [ "$SHOW_TRENDS" = "true" ] && [ $counter -gt 1 ]; then
            echo ""
            echo "  📊 ТРЕНДЫ:"
            local current_cpu=$(get_cpu_usage)
            local current_mem=$(get_memory_usage)
            
            analyze_trends "$current_cpu" "$previous_cpu" "CPU"
            analyze_trends "$current_mem" "$previous_mem" "Память"
            
            previous_cpu=$current_cpu
            previous_mem=$current_mem
        fi
        
        # Сохраняем историю
        save_metrics_history
        
        echo ""
        echo "  ⌛ Следующее обновление через $MONITOR_REFRESH_RATE секунд..."
        sleep "$MONITOR_REFRESH_RATE"
    done
}

# Экспорт метрик
export_metrics() {
    local format=${1:-"csv"}
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    case $format in
        "csv")
            local export_file="$METRICS_DIR/metrics_export_${timestamp}.csv"
            echo "timestamp,cpu_usage,memory_usage,disk_usage,temperature,load_1,load_5,load_15" > "$export_file"
            
            local cpu_usage=$(get_cpu_usage)
            local mem_usage=$(get_memory_usage)
            local disk_usage=$(get_disk_usage "/")
            local temp=$(get_temperature)
            local load_avg=($(get_load_average))
            
            echo "$(date +%Y-%m-%d\ %H:%M:%S),$cpu_usage,$mem_usage,$disk_usage,$temp,${load_avg[0]},${load_avg[1]},${load_avg[2]}" >> "$export_file"
            
            print_success "Метрики экспортированы в CSV: $export_file"
            ;;
        "json")
            if command -v jq &> /dev/null; then
                local export_file="$METRICS_DIR/metrics_export_${timestamp}.json"
                
                local cpu_usage=$(get_cpu_usage)
                local mem_usage=$(get_memory_usage)
                local disk_usage=$(get_disk_usage "/")
                local temp=$(get_temperature)
                local load_avg=($(get_load_average))
                local uptime=$(get_uptime)
                
                jq -n \
                  --arg timestamp "$(date -Iseconds)" \
                  --arg hostname "$(hostname)" \
                  --argjson cpu "$cpu_usage" \
                  --argjson memory "$mem_usage" \
                  --argjson disk "$disk_usage" \
                  --arg temperature "$temp" \
                  --arg load1 "${load_avg[0]}" \
                  --arg load5 "${load_avg[1]}" \
                  --arg load15 "${load_avg[2]}" \
                  --arg uptime "$uptime" \
                  '{
                    timestamp: $timestamp,
                    hostname: $hostname,
                    metrics: {
                      cpu_usage: $cpu,
                      memory_usage: $memory,
                      disk_usage: $disk,
                      temperature: $temperature,
                      load_average: {
                        load1: $load1,
                        load5: $load5,
                        load15: $load15
                      },
                      uptime: $uptime
                    }
                  }' > "$export_file"
                
                print_success "Метрики экспортированы в JSON: $export_file"
            else
                print_error "Для экспорта в JSON требуется утилита jq"
                echo "💡 Установите: sudo apt install jq"
            fi
            ;;
        *)
            print_error "Неизвестный формат экспорта: $format"
            echo "Доступные форматы: csv, json"
            ;;
    esac
}

# Анализ истории метрик
analyze_history() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        print_warning "Файл истории метрик не найден или пуст"
        return
    fi
    
    print_section "АНАЛИЗ ИСТОРИИ МЕТРИК"
    
    local total_records=$(wc -l < "$HISTORY_FILE" | awk '{print $1}')
    local data_records=$((total_records - 1))  # минус заголовок
    
    if [ "$data_records" -lt 2 ]; then
        echo "  ℹ️  Недостаточно данных для анализа"
        return
    fi
    
    echo "  📈 Статистика за $data_records записей:"
    
    # Анализ CPU
    local avg_cpu=$(awk -F, 'NR>1 {sum+=$2} END {if(NR>1) printf "%.1f", sum/(NR-1)}' "$HISTORY_FILE")
    local max_cpu=$(awk -F, 'NR>1 {if(max=="")max=$2; if($2>max) max=$2} END {print max}' "$HISTORY_FILE")
    
    echo "    💻 CPU: среднее=${avg_cpu}%, максимум=${max_cpu}%"
    
    # Анализ памяти
    local avg_mem=$(awk -F, 'NR>1 {sum+=$3} END {if(NR>1) printf "%.1f", sum/(NR-1)}' "$HISTORY_FILE")
    local max_mem=$(awk -F, 'NR>1 {if(max=="")max=$3; if($3>max) max=$3} END {print max}' "$HISTORY_FILE")
    
    echo "    🧠 Память: среднее=${avg_mem}%, максимум=${max_mem}%"
    
    # Предупреждения если средние значения высокие
    if (( $(echo "$avg_cpu > $THRESHOLD_CPU_WARNING" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "    ⚠️  Средняя загрузка CPU высокая"
    fi
    
    if (( $(echo "$avg_mem > $THRESHOLD_MEMORY_WARNING" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "    ⚠️  Среднее использование памяти высокое"
    fi
}

# Очистка старых данных
clean_old_data() {
    print_section "ОЧИСТКА СТАРЫХ ДАННЫХ"
    
    local retention_days=${HISTORY_RETENTION_DAYS:-30}
    local cutoff_date=$(date -d "$retention_days days ago" +%Y%m%d)
    local deleted_count=0
    
    # Очистка старых файлов экспорта
    for file in "$METRICS_DIR"/metrics_export_*.*; do
        if [ -f "$file" ]; then
            local file_date=$(echo "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | tr -d '-')
            if [ "$file_date" -lt "$cutoff_date" ]; then
                rm "$file"
                deleted_count=$((deleted_count + 1))
                echo "  🗑️  Удален: $(basename "$file")"
            fi
        fi
    done
    
    # Очистка кэша
    if [ -f "$CACHE_FILE" ]; then
        rm "$CACHE_FILE"
        echo "  🗑️  Очищен кэш метрик"
    fi
    
    if [ "$deleted_count" -eq 0 ]; then
        print_success "Нет старых данных для удаления"
    else
        print_success "Удалено файлов: $deleted_count"
    fi
}

# Основная функция
main() {
    load_config
    
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
            export_metrics "${2:-csv}"
            ;;
        "history")
            print_header
            analyze_history
            ;;
        "config")
            create_config
            ;;
        "clean")
            clean_old_data
            ;;
        "test")
            print_header
            check_dependencies
            print_success "Тестирование завершено"
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  overview        - Краткий обзор метрик"
            echo "  detailed        - Подробный отчет"
            echo "  monitor         - Продвинутый мониторинг"
            echo "  export [format] - Экспорт метрик (csv, json)"
            echo "  history         - Анализ истории метрик"
            echo "  config          - Создать конфигурацию"
            echo "  clean           - Очистка старых данных"
            echo "  test            - Тестирование системы"
            echo "  help            - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 overview"
            echo "  $0 monitor"
            echo "  $0 export json"
            echo "  $0 history"
            echo "  $0 clean"
            ;;
        *)
            print_error "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            exit 1
            ;;
    esac
}

# Инициализация
main "$@"
