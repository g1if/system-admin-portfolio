#!/bin/bash
# 🚀 Менеджер системных сервисов с автоопределением и мониторингом
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/config"
LOG_FILE="$LOG_DIR/service-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${MAGENTA}"
    echo "🚀 ==========================================="
    echo "   МЕНЕДЖЕР СИСТЕМНЫХ СЕРВИСОВ v1.1"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}🛠️  $1${NC}"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "  ${GREEN}✅ $message${NC}" ;;
        "WARN") echo -e "  ${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "  ${RED}❌ $message${NC}" ;;
        "INFO") echo -e "  ${BLUE}ℹ️  $message${NC}" ;;
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

# Определяем систему и менеджер сервисов
detect_service_manager() {
    if check_command "systemctl"; then
        echo "systemd"
    elif check_command "service"; then
        echo "sysvinit"
    elif check_command "rc-status"; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

# Получение статуса сервиса
get_service_status() {
    local service=$1
    local manager=$2
    
    case $manager in
        "systemd")
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "active"
            elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
                echo "inactive"
            else
                echo "not-found"
            fi
            ;;
        "sysvinit")
            if service "$service" status >/dev/null 2>&1; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Управление сервисом
manage_service() {
    local service=$1
    local action=$2
    local manager=$3
    
    case $manager in
        "systemd")
            case $action in
                "start") sudo systemctl start "$service" ;;
                "stop") sudo systemctl stop "$service" ;;
                "restart") sudo systemctl restart "$service" ;;
                "enable") sudo systemctl enable "$service" ;;
                "disable") sudo systemctl disable "$service" ;;
                "status") systemctl status "$service" ;;
            esac
            ;;
        "sysvinit")
            case $action in
                "start") sudo service "$service" start ;;
                "stop") sudo service "$service" stop ;;
                "restart") sudo service "$service" restart ;;
                "status") service "$service" status ;;
                *) echo "Действие $action не поддерживается в sysvinit" ;;
            esac
            ;;
    esac
}

# Получение списка сервисов
list_services() {
    local manager=$1
    local filter=${2:-""}
    
    case $manager in
        "systemd")
            if [ -z "$filter" ]; then
                systemctl list-units --type=service --all --no-legend | head -20
            else
                systemctl list-units --type=service --all --no-legend | grep "$filter" | head -20
            fi
            ;;
        "sysvinit")
            echo "Список сервисов для sysvinit требует ручного ввода"
            ;;
    esac
}

# Мониторинг сервисов в реальном времени
monitor_services() {
    local manager=$1
    local refresh_rate=${2:-5}
    
    echo -e "${CYAN}📊 Мониторинг сервисов (обновление каждые ${refresh_rate} сек)${NC}"
    echo -e "${CYAN}Для выхода нажмите Ctrl+C${NC}"
    
    while true; do
        clear
        print_header
        print_section "МОНИТОРИНГ СЕРВИСОВ - $(date)"
        
        case $manager in
            "systemd")
                echo -e "${YELLOW}🔧 Системные сервисы:${NC}"
                systemctl list-units --type=service --state=failed --no-legend
                echo ""
                
                echo -e "${YELLOW}📈 Статус критических сервисов:${NC}"
                local critical_services=("ssh" "nginx" "apache2" "mysql" "postgresql" "docker")
                for service in "${critical_services[@]}"; do
                    local status=$(get_service_status "$service" "$manager")
                    case $status in
                        "active") echo -e "  ${GREEN}✅ $service: запущен${NC}" ;;
                        "inactive") echo -e "  ${YELLOW}🟡 $service: остановлен${NC}" ;;
                        "not-found") echo -e "  ${BLUE}ℹ️  $service: не найден${NC}" ;;
                        *) echo -e "  ${RED}❓ $service: неизвестный статус${NC}" ;;
                    esac
                done
                ;;
            "sysvinit")
                echo -e "${YELLOW}📋 Доступные сервисов:${NC}"
                service --status-all | head -15
                ;;
        esac
        
        echo ""
        echo -e "${CYAN}Следующее обновление через ${refresh_rate} сек...${NC}"
        sleep "$refresh_rate"
    done
}

# Анализ логов сервиса
analyze_service_logs() {
    local service=$1
    local lines=${2:-20}
    
    echo -e "${YELLOW}📋 Логи сервиса $service (последние $lines строк):${NC}"
    
    # Попытка получить логи через journalctl
    if check_command "journalctl"; then
        sudo journalctl -u "$service" -n "$lines" --no-pager 2>/dev/null || \
        echo "  Логи через journalctl недоступны"
    else
        # Поиск логов в /var/log
        local log_files=("/var/log/${service}.log" "/var/log/${service}/error.log" "/var/log/syslog")
        for log_file in "${log_files[@]}"; do
            if [ -f "$log_file" ]; then
                echo "  Файл: $log_file"
                sudo tail -n "$lines" "$log_file" 2>/dev/null | while read -r line; do
                    echo "    $line"
                done
                return
            fi
        done
        echo "  Файлы логов не найдены"
    fi
}

# Автоматическое восстановление сервиса
auto_recover_service() {
    local service=$1
    local manager=$2
    
    echo -e "${YELLOW}🔄 Попытка восстановления сервиса $service...${NC}"
    
    local status=$(get_service_status "$service" "$manager")
    
    case $status in
        "failed"|"inactive")
            echo "  Перезапуск сервиса..."
            manage_service "$service" "restart" "$manager"
            
            # Проверяем результат
            sleep 2
            local new_status=$(get_service_status "$service" "$manager")
            if [ "$new_status" = "active" ]; then
                print_status "OK" "Сервис $service успешно восстановлен"
            else
                print_status "ERROR" "Не удалось восстановить сервис $service"
                analyze_service_logs "$service" 10
            fi
            ;;
        "active")
            print_status "OK" "Сервис $service уже работает"
            ;;
        "not-found")
            print_status "ERROR" "Сервис $service не найден в системе"
            ;;
    esac
}

# Создание конфигурации сервиса
create_service_config() {
    local service=$1
    local manager=$2
    
    local config_file="$CONFIG_DIR/${service}-monitor.conf"
    
    cat > "$config_file" << CONFIG
# Конфигурация мониторинга для сервиса: $service
# Создано: $(date)

SERVICE_NAME="$service"
SERVICE_MANAGER="$manager"
CHECK_INTERVAL="60"
MAX_RESTART_ATTEMPTS="3"
ALERT_EMAIL=""

# Действия при сбое
ON_FAILURE="restart"
ON_SUCCESS="log"

# Дополнительные настройки
LOG_LINES="50"
TIMEOUT="30"
CONFIG

    echo -e "${GREEN}✅ Создан файл конфигурации: $config_file${NC}"
}

# Основная функция
main() {
    local service_manager=$(detect_service_manager)
    
    if [ "$service_manager" = "unknown" ]; then
        echo -e "${RED}❌ Не удалось определить менеджер сервисов${NC}"
        exit 1
    fi
    
    print_header
    log "Запуск менеджера сервисов (менеджер: $service_manager)"
    
    echo -e "${CYAN}🔍 Обнаружен менеджер сервисов: $service_manager${NC}"
    
    print_section "СТАТУС СИСТЕМНЫХ СЕРВИСОВ"
    
    case $service_manager in
        "systemd")
            echo -e "${YELLOW}📊 Общее состояние:${NC}"
            systemctl --no-pager --state=failed | head -10
            
            echo -e "\n${YELLOW}🚨 Неудачные сервисы:${NC}"
            local failed_services=$(systemctl --failed --no-legend | awk '{print $1}')
            if [ -z "$failed_services" ]; then
                print_status "OK" "Нет неудачных сервисов"
            else
                print_status "ERROR" "Обнаружены неудачные сервисы:"
                echo "$failed_services" | while read -r service; do
                    echo "  ❌ $(echo $service | sed 's/●//g')"
                done
            fi
            ;;
        "sysvinit")
            echo -e "${YELLOW}📋 Статус сервисов:${NC}"
            service --status-all | head -15
            ;;
    esac
    
    print_section "КРИТИЧЕСКИЕ СЕРВИСЫ"
    
    local critical_services=("ssh" "systemd-journald" "dbus" "network-manager" "systemd-logind")
    for service in "${critical_services[@]}"; do
        local status=$(get_service_status "$service" "$service_manager")
        case $status in
            "active") echo -e "  ${GREEN}✅ $service${NC}" ;;
            "inactive") echo -e "  ${YELLOW}🟡 $service${NC}" ;;
            "not-found") echo -e "  ${BLUE}ℹ️  $service: не установлен${NC}" ;;
            *) echo -e "  ${RED}❓ $service: неизвестно${NC}" ;;
        esac
    done
    
    echo ""
    echo -e "${GREEN}✅ Анализ сервисов завершен${NC}"
    log "Анализ сервисов завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Функции для обработки команд
cmd_monitor() {
    local manager=$(detect_service_manager)
    local refresh_rate=${2:-5}
    monitor_services "$manager" "$refresh_rate"
}

cmd_start() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    manage_service "$2" "start" "$manager"
}

cmd_stop() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    manage_service "$2" "stop" "$manager"
}

cmd_restart() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    manage_service "$2" "restart" "$manager"
}

cmd_status() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    manage_service "$2" "status" "$manager"
}

cmd_logs() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local lines=${3:-20}
    analyze_service_logs "$2" "$lines"
}

cmd_recover() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    auto_recover_service "$2" "$manager"
}

cmd_list() {
    local manager=$(detect_service_manager)
    local filter=${2:-""}
    list_services "$manager" "$filter"
}

cmd_config() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите имя сервиса${NC}"
        exit 1
    fi
    local manager=$(detect_service_manager)
    create_service_config "$2" "$manager"
}

cmd_help() {
    echo -e "${CYAN}🚀 Менеджер системных сервисов - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА] [СЕРВИС] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  monitor [секунды]    - мониторинг сервисов в реальном времени"
    echo "  start <сервис>       - запустить сервис"
    echo "  stop <сервис>        - остановить сервис"
    echo "  restart <сервис>     - перезапустить сервис"
    echo "  status <сервис>      - показать статус сервиса"
    echo "  logs <сервис> [строк] - показать логи сервиса"
    echo "  recover <сервис>     - автоматическое восстановление сервиса"
    echo "  list [фильтр]        - список сервисов"
    echo "  config <сервис>      - создать конфиг для мониторинга сервиса"
    echo "  help                 - эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 monitor           - мониторинг всех сервисов"
    echo "  $0 start ssh         - запустить SSH сервис"
    echo "  $0 logs nginx 50     - показать 50 строк логов nginx"
    echo "  $0 recover apache2   - восстановить apache2"
    echo "  $0 list mysql        - найти сервисы с mysql в названии"
}

# Обработка аргументов
case "${1:-}" in
    "monitor") cmd_monitor "$@" ;;
    "start") cmd_start "$@" ;;
    "stop") cmd_stop "$@" ;;
    "restart") cmd_restart "$@" ;;
    "status") cmd_status "$@" ;;
    "logs") cmd_logs "$@" ;;
    "recover") cmd_recover "$@" ;;
    "list") cmd_list "$@" ;;
    "config") cmd_config "$@" ;;
    "help") cmd_help ;;
    *) main ;;
esac
