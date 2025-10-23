#!/bin/bash
# 🖥️ Умный системный монитор с автоопределением параметров
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -euo pipefail

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/system-monitor.log"

# Создаем директорию для логов
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
    echo "🖥️  ==========================================="
    echo "   СИСТЕМНЫЙ МОНИТОР v2.2"
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

# Функция для безопасного выполнения команд с обработкой ошибок
safe_exec() {
    local command="$1"
    local description="$2"
    
    if output=$($command 2>/dev/null); then
        echo "$output"
        return 0
    else
        log "Ошибка выполнения: $description"
        return 1
    fi
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
    CPU_CORES=$(nproc 2>/dev/null || echo "N/A")
    echo "  Процессор: $CPU_CORES ядер"
    
    CPU_USAGE="N/A"
    if check_command "mpstat"; then
        CPU_USAGE=$(mpstat 1 1 2>/dev/null | awk '$3 ~ /[0-9.]+/ {print 100 - $3"%"}' | tail -1)
    elif check_command "top"; then
        CPU_USAGE=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        CPU_USAGE="${CPU_USAGE}%"
    fi
    
    if [ "$CPU_USAGE" != "N/A" ]; then
        # Убираем символ % для сравнения
        CPU_NUM=$(echo "$CPU_USAGE" | sed 's/%//')
        if (( $(echo "$CPU_NUM > 80" | bc -l 2>/dev/null) )); then
            print_status "WARN" "Загрузка CPU: $CPU_USAGE"
        else
            print_status "OK" "Загрузка CPU: $CPU_USAGE"
        fi
    else
        echo "  Загрузка CPU: N/A"
    fi
    
    # Memory
    if check_command "free"; then
        MEM_INFO=$(free -h 2>/dev/null | grep Mem || echo "N/A")
        if [ "$MEM_INFO" != "N/A" ]; then
            MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
            MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
            MEM_PERCENT=$(free 2>/dev/null | grep Mem | awk '{printf "%.1f", $3/$2 * 100}' || echo "N/A")
            
            echo "  Память: $MEM_USED/$MEM_TOTAL"
            if [ "$MEM_PERCENT" != "N/A" ] && (( $(echo "$MEM_PERCENT > 80" | bc -l 2>/dev/null) )); then
                print_status "WARN" "Использование памяти: ${MEM_PERCENT}%"
            elif [ "$MEM_PERCENT" != "N/A" ]; then
                print_status "OK" "Использование памяти: ${MEM_PERCENT}%"
            fi
        fi
    else
        echo "  Память: N/A"
    fi
    
    # Disk
    if check_command "df"; then
        DF_OUTPUT=$(df -h / 2>/dev/null | tail -1)
        if [ -n "$DF_OUTPUT" ]; then
            DISK_USED=$(echo $DF_OUTPUT | awk '{print $3}')
            DISK_TOTAL=$(echo $DF_OUTPUT | awk '{print $2}')
            DISK_PERCENT=$(echo $DF_OUTPUT | awk '{print $5}' | sed 's/%//')
            
            echo "  Диск (/): $DISK_USED/$DISK_TOTAL"
            if [ "$DISK_PERCENT" -gt 90 ] 2>/dev/null; then
                print_status "ERROR" "Использование диска: ${DISK_PERCENT}%"
            elif [ "$DISK_PERCENT" -gt 80 ] 2>/dev/null; then
                print_status "WARN" "Использование диска: ${DISK_PERCENT}%"
            else
                print_status "OK" "Использование диска: ${DISK_PERCENT}%"
            fi
        else
            echo "  Диск: N/A"
        fi
    else
        echo "  Диск: N/A"
    fi
}

# Мониторинг сети
check_network() {
    print_section "СЕТЕВОЙ МОНИТОРИНГ"
    
    # Активные интерфейсы
    INTERFACE_FOUND=0
    if check_command "ip"; then
        INTERFACES=$(ip link show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "LOOPBACK" | awk -F: '{print $2}' | tr -d ' ' | head -3)
        
        for IFACE in $INTERFACES; do
            IP_ADDR=$(ip addr show $IFACE 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
            if [ -n "$IP_ADDR" ]; then
                echo "  $IFACE: $IP_ADDR"
                INTERFACE_FOUND=1
            fi
        done
    fi
    
    if [ $INTERFACE_FOUND -eq 0 ]; then
        echo "  Сетевые интерфейсы: не найдены"
    fi
    
    # Проверка интернета
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        print_status "OK" "Интернет соединение: Доступно"
    else
        print_status "WARN" "Интернет соединение: Не доступно"
    fi
}

# Мониторинг сервисов
check_services() {
    print_section "СИСТЕМНЫЕ СЕРВИСЫ"
    
    SERVICES=("ssh" "sshd" "nginx" "apache2" "mysql" "postgresql" "docker")
    SERVICE_FOUND=0
    
    for SERVICE in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
            print_status "OK" "Сервис $SERVICE: Запущен"
            SERVICE_FOUND=1
        elif command -v "$SERVICE" &>/dev/null; then
            print_status "WARN" "Сервис $SERVICE: Установлен, но не запущен"
            SERVICE_FOUND=1
        fi
    done
    
    if [ $SERVICE_FOUND -eq 0 ]; then
        echo "  Отслеживаемые сервисы: не найдены"
    fi
}

# Основная функция
main() {
    print_header
    log "Запуск системного монитора"
    
    detect_system
    check_resources
    check_network
    check_services
    
    echo ""
    echo -e "${GREEN}✅ Проверка завершена${NC}"
    log "Проверка системы завершена"
    echo ""
    echo -e "${CYAN}📝 Логи: $LOG_FILE${NC}"
}

# Обработка аргументов
case "${1:-}" in
    "watch")
        if check_command "watch"; then
            echo -e "${CYAN}🔍 Режим реального времени (обновление каждые 10 сек)${NC}"
            echo -e "${CYAN}Для выхода нажмите Ctrl+C${NC}"
            watch -n 10 -c "bash \"$SCRIPT_DIR/system-monitor.sh\" 2>/dev/null || echo \"Ошибка выполнения скрипта\""
        else
            echo "Команда 'watch' не найдена. Установите: sudo apt install watch"
        fi
        ;;
    "log")
        if [ -f "$LOG_FILE" ]; then
            echo -e "${CYAN}📋 Просмотр логов (для выхода Ctrl+C)${NC}"
            tail -f "$LOG_FILE"
        else
            echo "Лог-файл не найден: $LOG_FILE"
            echo "Сначала запустите: $0"
        fi
        ;;
    "help")
        echo "Использование: $0 [watch|log|help]"
        echo "  watch - мониторинг в реальном времени (каждые 10 сек)"
        echo "  log   - просмотр логов в реальном времени"
        echo "  help  - эта справка"
        ;;
    *)
        main
        ;;
esac
