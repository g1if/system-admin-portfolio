#!/bin/bash
# 🚀 Продвинутый менеджер системных сервисов с мониторингом и авто-восстановлением
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
LOG_FILE="$LOG_DIR/service-manager.log"
MAIN_CONFIG="$CONFIG_DIR/service-manager.conf"

# Создаем директории
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR"

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
    
    for cmd in systemctl service journalctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Отсутствуют системные утилиты: ${missing[*]}"
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
    
    # Также выводим в консоль если не в режиме мониторинга
    if [ "$MONITOR_MODE" != "true" ]; then
        case $level in
            "ERROR") echo -e "${RED}[ERROR] $message${NC}" ;;
            "WARN") echo -e "${YELLOW}[WARN] $message${NC}" ;;
            "INFO") echo -e "${BLUE}[INFO] $message${NC}" ;;
            *) echo "[$level] $message" ;;
        esac
    fi
}

print_header() {
    echo -e "${MAGENTA}"
    echo "🚀 ==========================================="
    echo "   ПРОДВИНУТЫЙ МЕНЕДЖЕР СЕРВИСОВ v2.0"
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
        "CRITICAL") echo -e "  ${RED}🚨 $message${NC}" ;;
    esac
}

# Создание конфигурации
create_config() {
    cat > "$MAIN_CONFIG" << 'EOF'
# Конфигурация менеджера сервисов v2.0

# Критические сервисы для мониторинга
CRITICAL_SERVICES=("ssh" "nginx" "mysql" "postgresql" "docker" "apache2" "systemd-journald" "dbus" "network-manager")

# Настройки мониторинга
MONITOR_REFRESH_RATE=5
MONITOR_TIMEOUT=30
MAX_RESTART_ATTEMPTS=3
RESTART_DELAY=5

# Настройки оповещений
ALERT_ENABLED=true
ALERT_METHODS=("console" "log")  # console, log, email, telegram
ALERT_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Настройки отчетов
REPORT_ENABLED=true
REPORT_RETENTION_DAYS=7
AUTO_GENERATE_REPORT=true

# Дополнительные настройки
ENABLE_AUTO_RECOVERY=true
LOG_RETENTION_DAYS=30
CHECK_DEPENDENCIES=true
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
        CRITICAL_SERVICES=("ssh" "nginx" "mysql" "postgresql" "docker" "apache2")
        MONITOR_REFRESH_RATE=5
        MAX_RESTART_ATTEMPTS=3
        RESTART_DELAY=5
        ALERT_ENABLED=true
        ALERT_METHODS=("console" "log")
        ENABLE_AUTO_RECOVERY=true
    fi
}

# Отправка оповещений
send_alert() {
    local level=$1
    local message=$2
    local service=${3:-""}
    
    if [ "$ALERT_ENABLED" != "true" ]; then
        return
    fi
    
    local full_message="[$level] $message"
    if [ -n "$service" ]; then
        full_message="[$level] Сервис $service: $message"
    fi
    
    # Логирование всегда
    log "$level" "$message"
    
    # Console оповещения
    if [[ " ${ALERT_METHODS[@]} " =~ " console " ]]; then
        case $level in
            "CRITICAL") print_status "CRITICAL" "$message" ;;
            "ERROR") print_status "ERROR" "$message" ;;
            "WARN") print_status "WARN" "$message" ;;
            *) print_status "INFO" "$message" ;;
        esac
    fi
    
    # Здесь можно добавить email и telegram оповещения
    # аналогично реализации в alert-system.sh
}

# Определяем систему и менеджер сервисов
detect_service_manager() {
    if command -v "systemctl" >/dev/null 2>&1; then
        echo "systemd"
        log "INFO" "Обнаружен systemd"
    elif command -v "service" >/dev/null 2>&1; then
        echo "sysvinit"
        log "INFO" "Обнаружен sysvinit"
    elif command -v "rc-status" >/dev/null 2>&1; then
        echo "openrc"
        log "INFO" "Обнаружен OpenRC"
    else
        echo "unknown"
        log "ERROR" "Не удалось определить менеджер сервисов"
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
        "openrc")
            if rc-status --servicelist | grep -q "$service" && rc-service "$service" status >/dev/null 2>&1; then
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

# Получение детальной информации о сервисе
get_service_details() {
    local service=$1
    local manager=$2
    
    case $manager in
        "systemd")
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
            local memory=$(systemctl show "$service" --property=MemoryCurrent | cut -d= -f2)
            local cpu_usage=$(ps -o pid,comm,%cpu --ppid 1 | grep "$service" | awk '{sum+=$3} END {print sum}')
            
            echo "Status: $status"
            echo "Enabled: $enabled"
            echo "Memory: ${memory:-0} bytes"
            echo "CPU: ${cpu_usage:-0}%"
            ;;
        *)
            echo "Детальная информация доступна только для systemd"
            ;;
    esac
}

# Управление сервисом
manage_service() {
    local service=$1
    local action=$2
    local manager=$3
    local attempts=1
    
    case $manager in
        "systemd")
            case $action in
                "start") 
                    sudo systemctl start "$service"
                    ;;
                "stop") 
                    sudo systemctl stop "$service"
                    ;;
                "restart") 
                    sudo systemctl restart "$service"
                    ;;
                "enable") 
                    sudo systemctl enable "$service"
                    ;;
                "disable") 
                    sudo systemctl disable "$service"
                    ;;
                "reload") 
                    sudo systemctl reload "$service"
                    ;;
                "status") 
                    systemctl status "$service" --no-pager
                    ;;
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
        "openrc")
            case $action in
                "start") sudo rc-service "$service" start ;;
                "stop") sudo rc-service "$service" stop ;;
                "restart") sudo rc-service "$service" restart ;;
                "status") sudo rc-service "$service" status ;;
                *) echo "Действие $action не поддерживается в OpenRC" ;;
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
                systemctl list-units --type=service --all --no-legend | awk '{print $1}' | sed 's/\.service$//'
            else
                systemctl list-units --type=service --all --no-legend | grep "$filter" | awk '{print $1}' | sed 's/\.service$//'
            fi
            ;;
        "sysvinit")
            service --status-all 2>/dev/null | grep -E "\[ \+ \]|\[ \- \]" | awk '{print $4}' || \
            ls /etc/init.d/ | grep -v README
            ;;
        "openrc")
            rc-status --servicelist 2>/dev/null || echo "Не удалось получить список сервисов OpenRC"
            ;;
    esac
}

# Мониторинг сервисов в реальном времени
monitor_services() {
    local manager=$1
    local refresh_rate=${2:-$MONITOR_REFRESH_RATE}
    local monitor_timeout=${3:-$MONITOR_TIMEOUT}
    
    export MONITOR_MODE="true"
    
    print_header
    echo -e "${CYAN}📊 Мониторинг сервисов (обновление каждые ${refresh_rate} сек)${NC}"
    echo -e "${CYAN}⏰ Таймаут: ${monitor_timeout} сек | Для выхода нажмите Ctrl+C${NC}"
    
    local start_time=$(date +%s)
    local counter=0
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Проверяем таймаут
        if [ $elapsed -ge $monitor_timeout ]; then
            echo -e "${YELLOW}⏰ Время мониторинга истекло${NC}"
            break
        fi
        
        counter=$((counter + 1))
        clear
        print_header
        print_section "МОНИТОРИНГ СЕРВИСОВ - Цикл #$counter ($(date '+%H:%M:%S'))"
        echo -e "${CYAN}Прошло: ${elapsed} сек | Осталось: $((monitor_timeout - elapsed)) сек${NC}"
        echo ""
        
        # Статус системы
        case $manager in
            "systemd")
                echo -e "${YELLOW}🔧 Общее состояние системы:${NC}"
                systemctl --no-pager --state=failed | head -5
                echo ""
                ;;
        esac
        
        # Критические сервисы
        echo -e "${YELLOW}🚨 Критические сервисы:${NC}"
        local has_critical_issues=0
        
        for service in "${CRITICAL_SERVICES[@]}"; do
            local status=$(get_service_status "$service" "$manager")
            local status_icon="✅"
            local color="$GREEN"
            
            case $status in
                "active") 
                    status_icon="✅"
                    color="$GREEN"
                    ;;
                "inactive") 
                    status_icon="🟡" 
                    color="$YELLOW"
                    has_critical_issues=$((has_critical_issues + 1))
                    ;;
                "not-found") 
                    status_icon="🔵"
                    color="$BLUE"
                    ;;
                *) 
                    status_icon="❓"
                    color="$RED"
                    has_critical_issues=$((has_critical_issues + 1))
                    ;;
            esac
            
            echo -e "  ${color}${status_icon} $service: $status${NC}"
        done
        
        # Статистика
        echo ""
        echo -e "${CYAN}📈 Статистика:${NC}"
        echo -e "  Всего критических сервисов: ${#CRITICAL_SERVICES[@]}"
        echo -e "  Проблемных сервисов: $has_critical_issues"
        echo -e "  Следующее обновление через: ${refresh_rate} сек"
        
        # Автоматическое восстановление
        if [ "$ENABLE_AUTO_RECOVERY" = "true" ] && [ $has_critical_issues -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}🔄 Авто-восстановление...${NC}"
            for service in "${CRITICAL_SERVICES[@]}"; do
                local status=$(get_service_status "$service" "$manager")
                if [ "$status" = "inactive" ]; then
                    echo -e "  Попытка восстановления $service..."
                    manage_service "$service" "start" "$manager" >/dev/null 2>&1
                    sleep 2
                    local new_status=$(get_service_status "$service" "$manager")
                    if [ "$new_status" = "active" ]; then
                        echo -e "  ${GREEN}✅ $service восстановлен${NC}"
                    else
                        echo -e "  ${RED}❌ Не удалось восстановить $service${NC}"
                    fi
                fi
            done
        fi
        
        sleep "$refresh_rate"
    done
    
    export MONITOR_MODE="false"
}

# Расширенный анализ логов сервиса
analyze_service_logs() {
    local service=$1
    local lines=${2:-50}
    local time_filter=${3:-"1 hour ago"}
    
    print_section "АНАЛИЗ ЛОГОВ СЕРВИСА: $service"
    
    # Попытка получить логи через journalctl
    if command -v journalctl >/dev/null 2>&1; then
        echo -e "${YELLOW}📋 Логи через journalctl (последние $lines строк):${NC}"
        
        # Основные логи
        sudo journalctl -u "$service" -n "$lines" --no-pager 2>/dev/null && return 0
        
        # Если не найдено, ищем по имени процесса
        sudo journalctl _COMM="$service" -n "$lines" --no-pager 2>/dev/null && return 0
    fi
    
    # Поиск логов в /var/log
    echo -e "${YELLOW}🔍 Поиск файлов логов в /var/log:${NC}"
    local log_files=(
        "/var/log/${service}.log"
        "/var/log/${service}/error.log"
        "/var/log/${service}/access.log"
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/daemon.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            echo -e "  📁 Файл: $log_file"
            sudo tail -n "$lines" "$log_file" 2>/dev/null | while read -r line; do
                echo "    $line"
            done
            return 0
        fi
    done
    
    echo -e "  ${RED}❌ Файлы логов не найдены${NC}"
    return 1
}

# Расширенное автоматическое восстановление сервиса
auto_recover_service() {
    local service=$1
    local manager=$2
    local max_attempts=${3:-$MAX_RESTART_ATTEMPTS}
    
    print_section "АВТО-ВОССТАНОВЛЕНИЕ СЕРВИСА: $service"
    
    local status=$(get_service_status "$service" "$manager")
    local attempt=1
    
    case $status in
        "failed"|"inactive")
            while [ $attempt -le $max_attempts ]; do
                echo -e "${YELLOW}🔄 Попытка $attempt из $max_attempts...${NC}"
                
                # Останавливаем если запущен некорректно
                if [ "$status" = "failed" ]; then
                    echo "  Останавливаем сервис..."
                    manage_service "$service" "stop" "$manager" >/dev/null 2>&1
                    sleep 2
                fi
                
                # Запускаем сервис
                echo "  Запускаем сервис..."
                manage_service "$service" "start" "$manager" >/dev/null 2>&1
                
                # Ждем и проверяем
                sleep $RESTART_DELAY
                local new_status=$(get_service_status "$service" "$manager")
                
                if [ "$new_status" = "active" ]; then
                    send_alert "INFO" "Сервис $service успешно восстановлен после $attempt попыток" "$service"
                    print_status "OK" "Сервис $service успешно восстановлен"
                    log "INFO" "Сервис $service восстановлен после $attempt попыток"
                    return 0
                else
                    echo -e "  ${RED}❌ Попытка $attempt не удалась${NC}"
                    attempt=$((attempt + 1))
                    sleep $RESTART_DELAY
                fi
            done
            
            send_alert "ERROR" "Не удалось восстановить сервис $service после $max_attempts попыток" "$service"
            print_status "ERROR" "Не удалось восстановить сервис $service"
            
            # Анализ логов для диагностики
            echo -e "${YELLOW}📋 Диагностика проблемы:${NC}"
            analyze_service_logs "$service" 20
            ;;
            
        "active")
            print_status "OK" "Сервис $service уже работает"
            ;;
            
        "not-found")
            print_status "ERROR" "Сервис $service не найден в системе"
            ;;
    esac
    
    return 1
}

# Генерация отчета
generate_report() {
    local manager=$1
    local report_file="$REPORTS_DIR/service-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ ОТЧЕТА"
    
    {
        echo "Отчет состояния сервисов"
        echo "Сгенерирован: $(date)"
        echo "Менеджер сервисов: $manager"
        echo "==========================================="
        echo ""
        
        echo "КРИТИЧЕСКИЕ СЕРВИСЫ:"
        echo "-------------------"
        for service in "${CRITICAL_SERVICES[@]}"; do
            local status=$(get_service_status "$service" "$manager")
            echo "$service: $status"
        done
        echo ""
        
        echo "НЕУДАЧНЫЕ СЕРВИСЫ:"
        echo "-----------------"
        case $manager in
            "systemd")
                systemctl --failed --no-legend | while read -r line; do
                    echo "$line"
                done
                ;;
        esac
        echo ""
        
        echo "СТАТИСТИКА СИСТЕМЫ:"
        echo "-----------------"
        case $manager in
            "systemd")
                echo "Всего сервисов: $(systemctl list-units --type=service --all --no-legend | wc -l)"
                echo "Активных: $(systemctl list-units --type=service --state=active --no-legend | wc -l)"
                echo "Неудачных: $(systemctl list-units --type=service --state=failed --no-legend | wc -l)"
                ;;
        esac
        
    } > "$report_file"
    
    print_status "OK" "Отчет сохранен: $report_file"
    log "INFO" "Сгенерирован отчет: $report_file"
    echo "$report_file"
}

# Валидация сервиса
validate_service() {
    local service=$1
    local manager=$2
    
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Имя сервиса не указано${NC}"
        return 1
    fi
    
    local status=$(get_service_status "$service" "$manager")
    
    if [ "$status" = "not-found" ]; then
        echo -e "${RED}❌ Сервис '$service' не найден${NC}"
        
        # Предлагаем похожие сервисы
        local similar=$(list_services "$manager" | grep "$service" | head -5)
        if [ -n "$similar" ]; then
            echo -e "${YELLOW}💡 Возможно вы имели в виду:${NC}"
            echo "$similar"
        fi
        return 1
    fi
    
    return 0
}

# Основная функция
main() {
    load_config
    
    if [ "$CHECK_DEPENDENCIES" = "true" ] && ! check_dependencies; then
        exit 1
    fi
    
    local service_manager=$(detect_service_manager)
    
    if [ "$service_manager" = "unknown" ]; then
        print_status "ERROR" "Не удалось определить менеджер сервисов"
        exit 1
    fi
    
    print_header
    log "INFO" "Запуск менеджера сервисов (менеджер: $service_manager)"
    
    echo -e "${CYAN}🔍 Обнаружен менеджер сервисов: $service_manager${NC}"
    
    # Быстрый статус
    print_section "БЫСТРЫЙ СТАТУС СИСТЕМЫ"
    
    case $service_manager in
        "systemd")
            local failed_count=$(systemctl --failed --no-legend | wc -l)
            if [ "$failed_count" -eq 0 ]; then
                print_status "OK" "Нет неудачных сервисов"
            else
                print_status "ERROR" "Обнаружены неудачные сервисы: $failed_count"
                systemctl --failed --no-legend | while read -r line; do
                    echo "  ❌ $(echo $line | awk '{print $2}')"
                done
            fi
            ;;
    esac
    
    print_section "СТАТУС КРИТИЧЕСКИХ СЕРВИСОВ"
    
    local problem_count=0
    for service in "${CRITICAL_SERVICES[@]}"; do
        local status=$(get_service_status "$service" "$service_manager")
        case $status in
            "active") 
                print_status "OK" "$service" 
                ;;
            "inactive") 
                print_status "ERROR" "$service - ОСТАНОВЛЕН"
                problem_count=$((problem_count + 1))
                ;;
            "not-found") 
                print_status "WARN" "$service - НЕ НАЙДЕН"
                ;;
            *) 
                print_status "ERROR" "$service - НЕИЗВЕСТНЫЙ СТАТУС"
                problem_count=$((problem_count + 1))
                ;;
        esac
    done
    
    echo ""
    if [ $problem_count -eq 0 ]; then
        print_status "OK" "Все критические сервисы работают нормально"
    else
        print_status "ERROR" "Обнаружено проблем: $problem_count"
    fi
    
    # Автогенерация отчета
    if [ "$AUTO_GENERATE_REPORT" = "true" ]; then
        echo ""
        generate_report "$service_manager" > /dev/null
    fi
    
    log "INFO" "Анализ сервисов завершен. Проблем: $problem_count"
}

# Команды
cmd_monitor() {
    local manager=$(detect_service_manager)
    local refresh_rate=${2:-$MONITOR_REFRESH_RATE}
    local timeout=${3:-$MONITOR_TIMEOUT}
    monitor_services "$manager" "$refresh_rate" "$timeout"
}

cmd_start() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    print_section "ЗАПУСК СЕРВИСА: $service"
    manage_service "$service" "start" "$manager"
    log "INFO" "Запуск сервиса: $service"
}

cmd_stop() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    print_section "ОСТАНОВКА СЕРВИСА: $service"
    manage_service "$service" "stop" "$manager"
    log "INFO" "Остановка сервиса: $service"
}

cmd_restart() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    print_section "ПЕРЕЗАПУСК СЕРВИСА: $service"
    manage_service "$service" "restart" "$manager"
    log "INFO" "Перезапуск сервиса: $service"
}

cmd_status() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    print_section "СТАТУС СЕРВИСА: $service"
    manage_service "$service" "status" "$manager"
}

cmd_logs() {
    local service="${2:-}"
    local lines="${3:-50}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    analyze_service_logs "$service" "$lines"
}

cmd_recover() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if ! validate_service "$service" "$manager"; then
        exit 1
    fi
    
    auto_recover_service "$service" "$manager"
}

cmd_list() {
    local manager=$(detect_service_manager)
    local filter="${2:-}"
    
    print_section "СПИСОК СЕРВИСОВ"
    list_services "$manager" "$filter"
}

cmd_config() {
    create_config
}

cmd_report() {
    local manager=$(detect_service_manager)
    generate_report "$manager"
}

cmd_validate() {
    local service="${2:-}"
    local manager=$(detect_service_manager)
    
    if validate_service "$service" "$manager"; then
        print_status "OK" "Сервис $service валиден"
        local status=$(get_service_status "$service" "$manager")
        local details=$(get_service_details "$service" "$manager")
        
        echo -e "${CYAN}📊 Детальная информация:${NC}"
        echo "$details"
    fi
}

cmd_help() {
    print_header
    echo -e "${CYAN}🚀 Продвинутый менеджер сервисов - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА] [СЕРВИС] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  monitor [секунды] [таймаут] - мониторинг сервисов в реальном времени"
    echo "  start <сервис>              - запустить сервис"
    echo "  stop <сервис>               - остановить сервис"
    echo "  restart <сервис>            - перезапустить сервис"
    echo "  status <сервис>             - показать статус сервиса"
    echo "  logs <сервис> [строк]       - показать логи сервиса"
    echo "  recover <сервис>            - автоматическое восстановление сервиса"
    echo "  list [фильтр]               - список сервисов"
    echo "  config                      - создать конфигурационный файл"
    echo "  report                      - генерация отчета"
    echo "  validate <сервис>           - проверка сервиса"
    echo "  help                        - эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 monitor                  - мониторинг всех сервисов"
    echo "  $0 monitor 10 300           - мониторинг с обновлением 10 сек, таймаут 5 мин"
    echo "  $0 start nginx              - запустить nginx"
    echo "  $0 logs mysql 100           - показать 100 строк логов mysql"
    echo "  $0 recover apache2          - восстановить apache2"
    echo "  $0 list docker              - найти сервисы с docker в названии"
    echo "  $0 validate ssh             - проверить сервис ssh"
    echo "  $0 report                   - сгенерировать отчет"
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
    "config") cmd_config ;;
    "report") cmd_report ;;
    "validate") cmd_validate "$@" ;;
    "help"|"--help"|"-h") cmd_help ;;
    *) main ;;
esac
