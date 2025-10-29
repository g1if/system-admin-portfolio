#!/bin/bash
# 🌐 Продвинутый анализатор сети с мониторингом, диагностикой и безопасностью
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
CACHE_DIR="$PROJECT_ROOT/cache"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$CACHE_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Конфигурация
CONFIG_FILE="$CONFIG_DIR/network-analyzer.conf"
MAIN_LOG="$LOG_DIR/network-analyzer.log"
CACHE_FILE="$CACHE_DIR/network-cache.db"
REPORT_FILE="$REPORTS_DIR/network-report-$(date +%Y%m%d_%H%M%S).txt"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🌐 ==========================================="
    echo "   ПРОДВИНУТЫЙ АНАЛИЗАТОР СЕТИ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📡 $1${NC}"
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
# Конфигурация сетевого анализатора v2.0

# Основные настройки
SCAN_INTERVAL=5
ENABLE_AUTO_DISCOVERY=true
SAVE_REPORTS=true
REPORT_RETENTION_DAYS=7

# Настройки сканирования портов
PORT_SCAN_ENABLED=true
PORT_SCAN_METHOD="nc"  # nc, telnet, nmap
SCAN_TIMEOUT=2
DEFAULT_PORTS="21,22,23,25,53,80,110,143,443,465,587,993,995,3389,5432,6379,27017"

# Настройки мониторинга
MONITOR_INTERVAL=3
MONITOR_PACKET_LOSS=true
MONITOR_BANDWIDTH=true
MONITOR_LATENCY=true

# Целевые хосты для проверки
TEST_HOSTS=(
    "8.8.8.8"           # Google DNS
    "1.1.1.1"           # Cloudflare DNS
    "google.com"
    "github.com"
    "localhost"
)

# Сетевые интерфейсы для мониторинга (автоопределение если пусто)
MONITOR_INTERFACES=""

# Настройки безопасности
CHECK_FIREWALL=true
CHECK_OPEN_PORTS=true
DETECT_SCANS=true

# Настройки производительности
ENABLE_CACHING=true
CACHE_TTL=300
MAX_LOG_SIZE=10485760

# Дополнительные настройки
ENABLE_SPEED_TEST=false
ENABLE_NETSTAT_ANALYSIS=true
ENABLE_ROUTING_ANALYSIS=true
ENABLE_DNS_ANALYSIS=true
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
        SCAN_INTERVAL=5
        PORT_SCAN_ENABLED=true
        DEFAULT_PORTS="21,22,23,25,53,80,110,143,443,465,587,993,995,3389"
        TEST_HOSTS=("8.8.8.8" "google.com" "localhost")
        ENABLE_CACHING=true
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in ip ping grep awk sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты
    if ! command -v nc &> /dev/null; then
        optional_missing+=("netcat")
    fi
    
    if ! command -v dig &> /dev/null; then
        optional_missing+=("dnsutils")
    fi
    
    if ! command -v nmap &> /dev/null; then
        optional_missing+=("nmap")
    fi
    
    if ! command -v speedtest-cli &> /dev/null && [ "$ENABLE_SPEED_TEST" = "true" ]; then
        optional_missing+=("speedtest-cli")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        print_warning "Отсутствуют опциональные утилиты: ${optional_missing[*]}"
        echo "💡 Для расширенных функций установите:"
        echo "   sudo apt install ${optional_missing[*]}"
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

# Получение сетевых интерфейсов
get_network_interfaces() {
    local cache_key="network_interfaces"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    local interfaces=()
    
    if command -v ip &> /dev/null; then
        interfaces=($(ip link show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "LOOPBACK" | awk -F: '{print $2}' | tr -d ' ' | sed 's/@.*//'))
    elif command -v ifconfig &> /dev/null; then
        interfaces=($(ifconfig -a 2>/dev/null | grep -E "^[a-z]" | awk '{print $1}' | tr -d ':'))
    fi
    
    local result=$(printf '%s ' "${interfaces[@]}")
    cache_set "$cache_key" "$result" 3600
    echo "$result"
}

# Детальный анализ интерфейса
analyze_interface_details() {
    local iface=$1
    print_section "ДЕТАЛЬНЫЙ АНАЛИЗ ИНТЕРФЕЙСА: $iface"
    
    if ! ip link show "$iface" &>/dev/null; then
        print_error "Интерфейс $iface не существует"
        return
    fi
    
    # Базовая информация
    echo "  🔌 Базовая информация:"
    local mac_addr=$(ip link show "$iface" 2>/dev/null | grep "link/ether" | awk '{print $2}')
    local status=$(ip link show "$iface" 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
    local mtu=$(ip link show "$iface" 2>/dev/null | grep -o "mtu [0-9]*" | awk '{print $2}')
    
    echo "    🔑 MAC адрес: ${mac_addr:-не доступен}"
    echo "    📊 Статус: $status"
    echo "    🏷️  MTU: ${mtu:-не доступен}"
    
    # IP информация
    echo "  📍 IP конфигурация:"
    ip addr show "$iface" 2>/dev/null | grep "inet " | while read -r line; do
        local ip_info=$(echo "$line" | awk '{print $2}')
        local scope=$(echo "$line" | grep -o "scope [a-z]*" | awk '{print $2}' || echo "global")
        echo "    🌐 $ip_info (scope: $scope)"
    done
    
    # Статистика
    echo "  📈 Статистика:"
    local rx_bytes=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx_bytes=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo "0")
    local rx_packets=$(cat "/sys/class/net/$iface/statistics/rx_packets" 2>/dev/null || echo "0")
    local tx_packets=$(cat "/sys/class/net/$iface/statistics/tx_packets" 2>/dev/null || echo "0")
    
    echo "    📥 Принято: $(numfmt --to=iec $rx_bytes) ($rx_packets пакетов)"
    echo "    📤 Отправлено: $(numfmt --to=iec $tx_bytes) ($tx_packets пакетов)"
    
    # Скорость в реальном времени (если включен мониторинг)
    if [ "$MONITOR_BANDWIDTH" = "true" ]; then
        local rx_speed=$(get_interface_speed "$iface" "rx")
        local tx_speed=$(get_interface_speed "$iface" "tx")
        echo "    🚀 Текущая скорость: RX ${rx_speed} KB/s, TX ${tx_speed} KB/s"
    fi
}

# Получение скорости интерфейса
get_interface_speed() {
    local iface=$1
    local direction=$2
    
    local stat_file="/sys/class/net/$iface/statistics/${direction}_bytes"
    if [ ! -f "$stat_file" ]; then
        echo "0"
        return
    fi
    
    local current_bytes=$(cat "$stat_file")
    local cache_key="${iface}_${direction}_bytes"
    local last_bytes=$(cache_get "$cache_key" || echo "$current_bytes")
    
    cache_set "$cache_key" "$current_bytes" 2
    
    local bytes_diff=$((current_bytes - last_bytes))
    local speed_kbs=$((bytes_diff / 1024))
    
    echo "$speed_kbs"
}

# Расширенный анализ интерфейсов
analyze_interfaces() {
    print_section "РАСШИРЕННЫЙ АНАЛИЗ СЕТЕВЫХ ИНТЕРФЕЙСОВ"
    
    local interfaces=($(get_network_interfaces))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        print_error "Сетевые интерфейсы не найдены"
        return
    fi
    
    echo "  📊 Обнаружено интерфейсов: ${#interfaces[@]}"
    echo ""
    
    for iface in "${interfaces[@]}"; do
        analyze_interface_details "$iface"
        echo ""
    done
    
    # Определение основного интерфейса
    local default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$default_interface" ]; then
        print_success "Основной интерфейс: $default_interface"
    fi
}

# Расширенный анализ маршрутизации
analyze_routing() {
    if [ "$ENABLE_ROUTING_ANALYSIS" != "true" ]; then
        return
    fi
    
    print_section "РАСШИРЕННАЯ ТАБЛИЦА МАРШРУТИЗАЦИИ"
    
    if command -v ip &> /dev/null; then
        echo "  🌍 Полная таблица маршрутизации:"
        ip route show 2>/dev/null | while read -r route; do
            if [[ $route == default* ]]; then
                echo -e "    🎯 ${GREEN}$route${NC}"
            elif [[ $route == *"scope link"* ]]; then
                echo "    🔗 $route"
            else
                echo "    🛣️  $route"
            fi
        done
        
        echo ""
        echo "  📊 Статистика маршрутизации:"
        local total_routes=$(ip route show 2>/dev/null | wc -l)
        local default_routes=$(ip route show 2>/dev/null | grep -c "default")
        echo "    📈 Всего маршрутов: $total_routes"
        echo "    🎯 Маршрутов по умолчанию: $default_routes"
        
    else
        print_warning "Команда 'ip' не найдена для анализа маршрутизации"
    fi
}

# Расширенный DNS анализ
analyze_dns() {
    if [ "$ENABLE_DNS_ANALYSIS" != "true" ]; then
        return
    fi
    
    print_section "РАСШИРЕННЫЙ DNS АНАЛИЗ"
    
    # DNS серверы
    echo "  🔍 Конфигурация DNS:"
    if [ -f /etc/resolv.conf ]; then
        local dns_servers=$(grep -E "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
        if [ -n "$dns_servers" ]; then
            echo "    🖥️  DNS серверы: $dns_servers"
        else
            print_warning "    DNS серверы не настроены в /etc/resolv.conf"
        fi
    else
        print_error "    Файл /etc/resolv.conf не найден"
    fi
    
    # Проверка DNS разрешения
    echo ""
    echo "  🔎 Проверка DNS разрешения:"
    
    local test_domains=("google.com" "github.com" "localhost")
    for domain in "${test_domains[@]}"; do
        if command -v dig &> /dev/null; then
            local result
            if result=$(dig +short "$domain" 2>/dev/null | head -1); then
                if [ -n "$result" ]; then
                    print_success "    $domain → $result"
                else
                    print_error "    $domain: не разрешается"
                fi
            fi
        elif command -v nslookup &> /dev/null; then
            if nslookup "$domain" &>/dev/null; then
                print_success "    $domain: разрешается"
            else
                print_error "    $domain: не разрешается"
            fi
        else
            # Простая проверка через ping
            if ping -c 1 -W 2 "$domain" &>/dev/null; then
                print_success "    $domain: доступен"
            else
                print_warning "    $domain: недоступен (может быть блокировка ICMP)"
            fi
            break
        fi
    done
    
    # DNS кэш (если systemd-resolve доступен)
    if command -v systemd-resolve &> /dev/null; then
        echo ""
        echo "  💾 DNS кэш (systemd-resolve):"
        systemd-resolve --statistics 2>/dev/null | grep -E "(Current Cache|Cache hits)" | head -5 | while read -r line; do
            echo "    📊 $line"
        done
    fi
}

# Расширенный анализ соединений
analyze_connections() {
    if [ "$ENABLE_NETSTAT_ANALYSIS" != "true" ]; then
        return
    fi
    
    print_section "РАСШИРЕННЫЙ АНАЛИЗ СОЕДИНЕНИЙ"
    
    local total_connections=0
    local established_connections=0
    
    if command -v ss &> /dev/null; then
        echo "  🔗 Детальная статистика соединений:"
        
        # TCP соединения
        local tcp_listen=$(ss -tuln 2>/dev/null | grep -c "LISTEN")
        local tcp_established=$(ss -tun 2>/dev/null | grep -c "ESTAB")
        
        echo "    🟢 TCP слушающих портов: $tcp_listen"
        echo "    🔗 TCP установленных соединений: $tcp_established"
        
        # Топ процессов по соединениям
        echo ""
        echo "  📊 Топ процессов по сетевой активности:"
        ss -tunp 2>/dev/null | grep ESTAB | awk '{print $7}' | cut -d\" -f2 | sort | uniq -c | sort -nr | head -5 | while read -r count process; do
            echo "    🚀 $process: $count соединений"
        done
        
        # Показать необычные соединения
        echo ""
        echo "  🔍 Необычные соединения:"
        ss -tun 2>/dev/null | grep ESTAB | awk '{print $6}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -3 | while read -r count ip; do
            if [ "$count" -gt 10 ]; then
                print_warning "    Подозрительная активность: $ip ($count соединений)"
            fi
        done
        
    else
        print_warning "Команда 'ss' не найдена для детального анализа соединений"
    fi
}

# Продвинутое сканирование портов
advanced_port_scan() {
    if [ "$PORT_SCAN_ENABLED" != "true" ]; then
        return
    fi
    
    print_section "ПРОДВИНУТОЕ СКАНИРОВАНИЕ ПОРТОВ"
    
    local target=${1:-"localhost"}
    local ports=()
    
    # Преобразуем строку портов в массив
    IFS=',' read -ra ports <<< "$DEFAULT_PORTS"
    
    echo "  🔎 Сканирование портов на $target..."
    echo "  📋 Проверяемые порты: ${ports[*]}"
    echo ""
    
    local open_ports=()
    local closed_ports=()
    
    for port in "${ports[@]}"; do
        if command -v nc &> /dev/null && [ "$PORT_SCAN_METHOD" = "nc" ]; then
            if nc -z -w "$SCAN_TIMEOUT" "$target" "$port" &>/dev/null; then
                open_ports+=("$port")
                print_success "    Порт $port: открыт"
            else
                closed_ports+=("$port")
                echo "    🔒 Порт $port: закрыт"
            fi
        elif command -v telnet &> /dev/null; then
            # Альтернативный метод с telnet
            if timeout "$SCAN_TIMEOUT" telnet "$target" "$port" &>/dev/null; then
                open_ports+=("$port")
                print_success "    Порт $port: открыт"
            else
                closed_ports+=("$port")
                echo "    🔒 Порт $port: закрыт"
            fi
        else
            print_warning "    Нет доступных инструментов для сканирования портов"
            return
        fi
    done
    
    echo ""
    echo "  📊 Результаты сканирования:"
    echo "    🟢 Открытых портов: ${#open_ports[@]}"
    echo "    🔒 Закрытых портов: ${#closed_ports[@]}"
    
    if [ ${#open_ports[@]} -gt 0 ]; then
        echo "    📍 Открытые порты: ${open_ports[*]}"
    fi
    
    # Проверка безопасности
    if [ ${#open_ports[@]} -gt 10 ]; then
        print_warning "    Обнаружено много открытых портов. Рекомендуется проверить настройки безопасности."
    fi
}

# Расширенная проверка скорости и задержки
advanced_speed_test() {
    print_section "РАСШИРЕННАЯ ПРОВЕРКА СКОРОСТИ И ЗАДЕРЖКИ"
    
    echo "  📊 Измерение сетевых характеристик..."
    echo ""
    
    # Проверка задержки до нескольких хостов
    echo "  🏓 Проверка задержки (ping):"
    for host in "${TEST_HOSTS[@]}"; do
        if [ "$host" = "localhost" ]; then
            continue
        fi
        
        local ping_result
        if ping_result=$(ping -c 3 -W 2 "$host" 2>/dev/null); then
            local avg_ping=$(echo "$ping_result" | grep "avg" | awk -F'/' '{print $5}')
            local packet_loss=$(echo "$ping_result" | grep -o "[0-9]*% packet loss" | cut -d% -f1)
            
            if [ -n "$avg_ping" ]; then
                echo -n "    $host: ${avg_ping}ms"
                
                if [ "$packet_loss" -gt 0 ]; then
                    echo -e " ${YELLOW}(потеря: ${packet_loss}%)${NC}"
                elif (( $(echo "$avg_ping < 50" | bc -l 2>/dev/null || echo 1) )); then
                    echo -e " ${GREEN}✅ Отлично${NC}"
                elif (( $(echo "$avg_ping < 100" | bc -l 2>/dev/null || echo 1) )); then
                    echo -e " ${YELLOW}⚠️  Нормально${NC}"
                else
                    echo -e " ${RED}❌ Высокая задержка${NC}"
                fi
            fi
        else
            print_error "    $host: недоступен"
        fi
    done
    
    # Speedtest если установлен
    if [ "$ENABLE_SPEED_TEST" = "true" ] && command -v speedtest-cli &> /dev/null; then
        echo ""
        echo "  🚀 Тест скорости интернета (может занять время)..."
        speedtest-cli --simple 2>/dev/null | while read -r line; do
            echo "    📊 $line"
        done
    else
        echo ""
        print_info "Для теста скорости установите: sudo apt install speedtest-cli"
    fi
    
    # Проверка пропускной способности локальной сети
    echo ""
    echo "  📡 Проверка локальной сети:"
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ] && [ "$gateway" != "169.254."* ]; then
        if ping -c 2 -W 1 "$gateway" &>/dev/null; then
            print_success "    Шлюз $gateway: доступен"
            
            # Измерение задержки до шлюза
            local gateway_ping=$(ping -c 3 -W 1 "$gateway" 2>/dev/null | grep "avg" | awk -F'/' '{print $5}')
            if [ -n "$gateway_ping" ]; then
                if (( $(echo "$gateway_ping < 5" | bc -l 2>/dev/null || echo 1) )); then
                    echo -e "      ${GREEN}Задержка до шлюза: ${gateway_ping}ms ✅${NC}"
                else
                    echo -e "      ${YELLOW}Задержка до шлюза: ${gateway_ping}ms ⚠️${NC}"
                fi
            fi
        else
            print_error "    Шлюз $gateway: недоступен"
        fi
    fi
}

# Анализ безопасности
analyze_security() {
    print_section "АНАЛИЗ БЕЗОПАСНОСТИ СЕТИ"
    
    # Проверка firewall
    if [ "$CHECK_FIREWALL" = "true" ]; then
        echo "  🔥 Проверка firewall:"
        
        if command -v ufw &> /dev/null; then
            local ufw_status=$(ufw status 2>/dev/null | grep "Status:")
            if echo "$ufw_status" | grep -q "active"; then
                print_success "    UFW: активен"
            else
                print_warning "    UFW: не активен"
            fi
        elif command -v iptables &> /dev/null; then
            local iptables_rules=$(iptables -L 2>/dev/null | grep -c "^Chain")
            if [ "$iptables_rules" -gt 3 ]; then
                print_success "    iptables: настроен ($iptables_rules правил)"
            else
                print_warning "    iptables: минимальная конфигурация"
            fi
        else
            print_error "    Firewall: не обнаружен"
        fi
    fi
    
    # Проверка подозрительных служб
    echo ""
    echo "  🔍 Проверка сетевых служб:"
    local suspicious_ports=("23" "135" "137" "138" "139" "445")
    for port in "${suspicious_ports[@]}"; do
        if nc -z localhost "$port" &>/dev/null; then
            print_warning "    Порт $port: открыт (потенциально опасная служба)"
        fi
    done
    
    # Проверка SSH конфигурации
    if nc -z localhost 22 &>/dev/null; then
        echo ""
        echo "  🔐 SSH сервер:"
        print_success "    Порт 22: открыт"
        # Дополнительные проверки SSH можно добавить здесь
    fi
}

# Режим мониторинга в реальном времени
monitor_mode() {
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_section "РЕЖИМ МОНИТОРИНГА В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Обновление каждые $MONITOR_INTERVAL секунд..."
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "  🔄 Цикл мониторинга: $counter"
        echo "  ⏰ Время: $(date '+%H:%M:%S')"
        echo "  ==================================="
        
        # Быстрый обзор интерфейсов
        print_section "СТАТУС ИНТЕРФЕЙСОВ"
        local interfaces=($(get_network_interfaces))
        for iface in "${interfaces[@]}"; do
            local status=$(ip link show "$iface" 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
            local ip_addr=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
            
            echo -n "  🔌 $iface: $status"
            if [ -n "$ip_addr" ]; then
                echo -e " - ${GREEN}$ip_addr${NC}"
            else
                echo -e " - ${YELLOW}нет IP${NC}"
            fi
            
            # Показываем скорость если включено
            if [ "$MONITOR_BANDWIDTH" = "true" ]; then
                local rx_speed=$(get_interface_speed "$iface" "rx")
                local tx_speed=$(get_interface_speed "$iface" "tx")
                echo "     📊 Скорость: RX ${rx_speed} KB/s, TX ${tx_speed} KB/s"
            fi
        done
        
        # Активные соединения
        echo ""
        print_section "АКТИВНЫЕ СОЕДИНЕНИЯ"
        local conn_count=$(ss -tun 2>/dev/null | grep -c ESTAB)
        echo "  🔗 Установленных соединений: $conn_count"
        
        # Быстрая проверка задержки
        if [ "$MONITOR_LATENCY" = "true" ] && [ $((counter % 5)) -eq 0 ]; then
            echo ""
            echo "  🏓 Быстрая проверка задержки:"
            for host in "8.8.8.8" "google.com"; do
                local ping_time=$(ping -c 1 -W 1 "$host" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "timeout")
                echo "    $host: $ping_time"
            done
        fi
        
        echo ""
        echo "  ⌛ Следующее обновление через $MONITOR_INTERVAL секунд..."
        sleep "$MONITOR_INTERVAL"
    done
}

# Генерация отчета
generate_report() {
    print_header > "$REPORT_FILE"
    echo "📅 Отчет создан: $(date)" >> "$REPORT_FILE"
    echo "💻 Система: $(hostname) ($(uname -a))" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Сбор данных в отчет
    analyze_interfaces >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    analyze_routing >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    analyze_dns >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    analyze_connections >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    advanced_port_scan >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    analyze_security >> "$REPORT_FILE" 2>&1
    
    print_success "Отчет сохранен: $REPORT_FILE"
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "quick")
            print_header
            analyze_interfaces
            analyze_dns
            advanced_speed_test
            ;;
        "monitor")
            print_header
            monitor_mode
            ;;
        "scan")
            print_header
            advanced_port_scan "${2:-localhost}"
            ;;
        "security")
            print_header
            analyze_security
            advanced_port_scan "localhost"
            ;;
        "report")
            print_header
            generate_report
            ;;
        "config")
            create_config
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
            echo "  quick           - Быстрый анализ основных параметров"
            echo "  monitor         - Мониторинг в реальном времени"
            echo "  scan [хост]     - Сканирование портов (по умолчанию: localhost)"
            echo "  security        - Анализ безопасности сети"
            echo "  report          - Генерация полного отчета"
            echo "  config          - Создать конфигурационный файл"
            echo "  test            - Тестирование системы"
            echo "  help            - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 quick"
            echo "  $0 monitor"
            echo "  $0 scan 192.168.1.1"
            echo "  $0 security"
            echo "  $0 report"
            ;;
        *)
            print_header
            analyze_interfaces
            analyze_routing
            analyze_dns
            analyze_connections
            advanced_port_scan "localhost"
            advanced_speed_test
            analyze_security
            ;;
    esac
}

# Инициализация
log_message "INFO" "Запуск сетевого анализатора"
main "$@"
log_message "INFO" "Завершение работы"
