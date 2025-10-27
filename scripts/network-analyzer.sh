#!/bin/bash
# 🌐 Анализатор сети с автоопределением параметров
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/network-analyzer.log"

# Создаем директории
mkdir -p "$LOG_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "🌐 ==========================================="
    echo "   АНАЛИЗАТОР СЕТИ v1.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📡 $1${NC}"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "  ${GREEN}✅ $message${NC}" ;;
        "WARN") echo -e "  ${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "  ${RED}❌ $message${NC}" ;;
    esac
}

# Проверка наличия команд
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Получение активных сетевых интерфейсов
get_network_interfaces() {
    local interfaces=()
    
    if check_command "ip"; then
        interfaces=($(ip link show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "LOOPBACK" | awk -F: '{print $2}' | tr -d ' '))
    elif check_command "ifconfig"; then
        interfaces=($(ifconfig -a 2>/dev/null | grep -E "^[a-z]" | awk '{print $1}' | tr -d ':'))
    fi
    
    printf '%s\n' "${interfaces[@]}"
}

# Анализ сетевых интерфейсов
analyze_interfaces() {
    print_section "СЕТЕВЫЕ ИНТЕРФЕЙСЫ"
    
    local interfaces=($(get_network_interfaces))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "  ℹ️  Сетевые интерфейсы не найдены"
        return
    fi
    
    for iface in "${interfaces[@]}"; do
        echo "  🔌 Интерфейс: $iface"
        
        # Получение IP адреса
        local ip_addr=""
        if check_command "ip"; then
            ip_addr=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
        elif check_command "ifconfig"; then
            ip_addr=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
        fi
        
        if [ -n "$ip_addr" ]; then
            echo "    📍 IP адрес: $ip_addr"
        else
            echo "    📍 IP адрес: не назначен"
        fi
        
        # Статус интерфейса
        if check_command "ip"; then
            local status=$(ip link show "$iface" 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
            echo "    📊 Статус: $status"
        fi
        
        # MAC адрес
        if check_command "ip"; then
            local mac_addr=$(ip link show "$iface" 2>/dev/null | grep "link/ether" | awk '{print $2}')
            if [ -n "$mac_addr" ]; then
                echo "    🔑 MAC адрес: $mac_addr"
            fi
        fi
        
        echo ""
    done
}

# Анализ маршрутизации
analyze_routing() {
    print_section "ТАБЛИЦА МАРШРУТИЗАЦИИ"
    
    if check_command "ip"; then
        echo "  🌍 Таблица маршрутизации:"
        ip route show 2>/dev/null | head -10 | while read -r route; do
            echo "    🛣️  $route"
        done
    elif check_command "netstat"; then
        echo "  🌍 Таблица маршрутизации:"
        netstat -rn 2>/dev/null | head -10 | while read -r route; do
            echo "    🛣️  $route"
        done
    else
        echo "  ℹ️  Команды для анализа маршрутизации не найдены"
    fi
}

# Проверка DNS
analyze_dns() {
    print_section "DNS НАСТРОЙКИ"
    
    # Получаем DNS серверы
    if [ -f /etc/resolv.conf ]; then
        echo "  🔍 DNS серверы:"
        grep -E "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    🖥️  " $2}' || echo "    ℹ️  Не настроены"
    else
        echo "  ℹ️  Файл resolv.conf не найден"
    fi
    
    # Проверка DNS разрешения
    if check_command "nslookup"; then
        echo "  🔎 Проверка DNS разрешения..."
        if nslookup google.com >/dev/null 2>&1; then
            print_status "OK" "DNS разрешение работает"
        else
            print_status "ERROR" "DNS разрешение не работает"
        fi
    elif check_command "dig"; then
        echo "  🔎 Проверка DNS разрешения..."
        if dig google.com >/dev/null 2>&1; then
            print_status "OK" "DNS разрешение работает"
        else
            print_status "ERROR" "DNS разрешение не работает"
        fi
    fi
}

# Анализ сетевых соединений
analyze_connections() {
    print_section "СЕТЕВЫЕ СОЕДИНЕНИЯ"
    
    local connection_count=0
    
    if check_command "ss"; then
        echo "  🔗 Активные соединения:"
        ss -tun 2>/dev/null | head -15 | while read -r line; do
            if [[ $line == ESTAB* ]]; then
                local proto=$(echo "$line" | awk '{print $1}')
                local local_addr=$(echo "$line" | awk '{print $5}')
                local remote_addr=$(echo "$line" | awk '{print $6}')
                echo "    🌐 $proto: $local_addr ➔ $remote_addr"
                connection_count=$((connection_count + 1))
            fi
        done
    elif check_command "netstat"; then
        echo "  🔗 Активные соединения:"
        netstat -tun 2>/dev/null | grep ESTABLISHED | head -15 | while read -r line; do
            local proto=$(echo "$line" | awk '{print $1}')
            local local_addr=$(echo "$line" | awk '{print $4}')
            local remote_addr=$(echo "$line" | awk '{print $5}')
            echo "    🌐 $proto: $local_addr ➔ $remote_addr"
            connection_count=$((connection_count + 1))
        done
    else
        echo "  ℹ️  Команды для анализа соединений не найдены"
    fi
    
    if [ "$connection_count" -eq 0 ]; then
        echo "    ℹ️  Активные соединения не найдены"
    fi
}

# Проверка скорости сети
check_network_speed() {
    print_section "ПРОВЕРКА СКОРОСТИ СЕТИ"
    
    echo "  📊 Измерение скорости (может занять несколько секунд)..."
    
    # Простая проверка с помощью ping
    if check_command "ping"; then
        local ping_result
        if ping_result=$(ping -c 3 -W 2 8.8.8.8 2>/dev/null); then
            local avg_ping=$(echo "$ping_result" | grep "avg" | awk -F'/' '{print $5}')
            if [ -n "$avg_ping" ]; then
                echo "    🏓 Средняя задержка: ${avg_ping}ms"
                
                if (( $(echo "$avg_ping < 50" | bc -l 2>/dev/null || echo 1) )); then
                    print_status "OK" "Задержка в норме"
                elif (( $(echo "$avg_ping < 100" | bc -l 2>/dev/null || echo 1) )); then
                    print_status "WARN" "Задержка немного высокая"
                else
                    print_status "ERROR" "Высокая задержка"
                fi
            fi
        else
            print_status "ERROR" "Не удалось измерить задержку"
        fi
    else
        echo "    ℹ️  Команда ping не найдена"
    fi
}

# Сканирование портов (базовое)
scan_ports() {
    print_section "БАЗОВОЕ СКАНИРОВАНИЕ ПОРТОВ"
    
    if check_command "nc"; then
        echo "  🔎 Проверка основных портов на localhost..."
        
        local common_ports=(22 80 443 53 21 25 110 143 993 995 587 465 3389 5900)
        local open_ports=()
        
        for port in "${common_ports[@]}"; do
            if nc -z localhost "$port" 2>/dev/null; then
                open_ports+=("$port")
                echo "    🟢 Порт $port: открыт"
            fi
        done
        
        if [ ${#open_ports[@]} -eq 0 ]; then
            echo "    ℹ️  Ни один из проверяемых портов не открыт"
        else
            echo "    📈 Открытых портов: ${#open_ports[@]}"
        fi
        
    elif check_command "telnet"; then
        echo "  🔎 Базовая проверка портов (требует telnet)..."
        # Альтернативная проверка с telnet
        print_status "INFO" "Для сканирования портов установите netcat (nc)"
    else
        echo "    ℹ️  Инструменты для сканирования портов не найдены"
    fi
}

# Основная функция
main() {
    print_header
    log "Запуск анализа сети"
    
    analyze_interfaces
    analyze_routing
    analyze_dns
    analyze_connections
    check_network_speed
    scan_ports
    
    echo ""
    echo -e "${GREEN}✅ Анализ сети завершен${NC}"
    log "Анализ сети завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Обработка аргументов
case "${1:-}" in
    "quick")
        echo -e "${CYAN}🌐 Быстрый анализ сети...${NC}"
        analyze_interfaces
        analyze_dns
        check_network_speed
        ;;
    "monitor")
        echo -e "${CYAN}📊 Мониторинг сети (обновление каждые 5 сек)...${NC}"
        echo -e "${CYAN}Для выхода нажмите Ctrl+C${NC}"
        while true; do
            clear
            print_header
            analyze_interfaces
            analyze_connections
            sleep 5
        done
        ;;
    "help")
        echo "Использование: $0 [quick|monitor|help]"
        echo "  quick   - быстрый анализ основных параметров"
        echo "  monitor - мониторинг сети в реальном времени"
        echo "  help    - эта справка"
        echo ""
        echo "Без аргументов: полный анализ сети"
        ;;
    *)
        main
        ;;
esac
