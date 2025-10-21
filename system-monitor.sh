#!/bin/bash
# 🖥️ Умный системный монитор с автоопределением параметров
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="../logs/system-monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "🖥️  ==========================================="
    echo "   СИСТЕМНЫЙ МОНИТОР v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
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
    esac
}

# Автоопределение системных параметров
detect_system() {
    print_section "СИСТЕМНАЯ ИНФОРМАЦИЯ"
    
    # Определение дистрибутива
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
    
    echo "  ОС: $OS_NAME $OS_VERSION"
    echo "  Хостнейм: $(hostname)"
    echo "  Ядро: $(uname -r)"
    echo "  Архитектура: $(uname -m)"
    
    # Uptime
    UPTIME=$(uptime -p 2>/dev/null || echo "Не доступно")
    echo "  Время работы: $UPTIME"
}

# Мониторинг ресурсов
check_resources() {
    print_section "МОНИТОРИНГ РЕСУРСОВ"
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    CPU_CORES=$(nproc)
    echo "  Процессор: $CPU_CORES ядер"
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l 2>/dev/null || echo "0") )); then
        print_status "WARN" "Загрузка CPU: ${CPU_USAGE}%"
    else
        print_status "OK" "Загрузка CPU: ${CPU_USAGE}%"
    fi
    
    # Memory
    MEM_INFO=$(free -h | grep Mem)
    MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
    MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
    MEM_PERCENT=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    
    echo "  Память: $MEM_USED/$MEM_TOTAL"
    if (( $(echo "$MEM_PERCENT > 80" | bc -l 2>/dev/null || echo "0") )); then
        print_status "WARN" "Использование памяти: ${MEM_PERCENT}%"
    else
        print_status "OK" "Использование памяти: ${MEM_PERCENT}%"
    fi
    
    # Disk
    DF_OUTPUT=$(df -h / | tail -1)
    DISK_USED=$(echo $DF_OUTPUT | awk '{print $3}')
    DISK_TOTAL=$(echo $DF_OUTPUT | awk '{print $2}')
    DISK_PERCENT=$(echo $DF_OUTPUT | awk '{print $5}' | cut -d'%' -f1)
    
    echo "  Диск (/): $DISK_USED/$DISK_TOTAL"
    if [ "$DISK_PERCENT" -gt 90 ]; then
        print_status "ERROR" "Использование диска: ${DISK_PERCENT}%"
    elif [ "$DISK_PERCENT" -gt 80 ]; then
        print_status "WARN" "Использование диска: ${DISK_PERCENT}%"
    else
        print_status "OK" "Использование диска: ${DISK_PERCENT}%"
    fi
}

# Мониторинг сети
check_network() {
    print_section "СЕТЕВОЙ МОНИТОРИНГ"
    
    # Активные интерфейсы
    INTERFACES=$(ip link show | grep -E "^[0-9]+:" | grep -v "LOOPBACK" | awk -F: '{print $2}' | tr -d ' ')
    
    for IFACE in $INTERFACES; do
        IP_ADDR=$(ip addr show $IFACE 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
        if [ -n "$IP_ADDR" ]; then
            echo "  $IFACE: $IP_ADDR"
        fi
    done
    
    # Проверка интернета
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        print_status "OK" "Интернет соединение: Доступно"
    else
        print_status "ERROR" "Интернет соединение: Не доступно"
    fi
}

# Мониторинг сервисов
check_services() {
    print_section "СИСТЕМНЫЕ СЕРВИСЫ"
    
    SERVICES=("ssh" "nginx" "apache2" "mysql" "postgresql")
    
    for SERVICE in "${SERVICES[@]}"; do
        if systemctl is-active --quiet $SERVICE 2>/dev/null; then
            print_status "OK" "Сервис $SERVICE: Запущен"
        elif command -v $SERVICE &>/dev/null; then
            print_status "WARN" "Сервис $SERVICE: Установлен, но не запущен"
        fi
    done
}

# Основная функция
main() {
    print_header
    detect_system
    check_resources
    check_network
    check_services
    
    echo ""
    echo -e "${GREEN}✅ Проверка завершена${NC}"
    log "System check completed"
}

# Обработка аргументов
case "${1:-}" in
    "watch")
        watch -n 10 "bash system-monitor.sh"
        ;;
    "log")
        tail -f "$LOG_FILE"
        ;;
    "help")
        echo "Использование: $0 [watch|log|help]"
        echo "  watch - мониторинг в реальном времени (каждые 10 сек)"
        echo "  log   - просмотр логов"
        echo "  help  - эта справка"
        ;;
    *)
        main
        ;;
esac
