#!/bin/bash
# 🔥 Расширенный менеджер фаервола (UFW/iptables/firewalld)
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
BACKUP_DIR="$PROJECT_ROOT/backups"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR"

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
FIREWALL_CONFIG="$CONFIG_DIR/firewall.conf"
FIREWALL_LOG="$LOG_DIR/firewall-manager.log"
BACKUP_FILE="$BACKUP_DIR/firewall-backup-$(date +%Y%m%d_%H%M%S).rules"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🔥 ==========================================="
    echo "   МЕНЕДЖЕР ФАЕРВОЛА v2.0"
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

# Логирование
log_action() {
    local action=$1
    local message=$2
    local level=${3:-"INFO"}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] [$action] $message" >> "$FIREWALL_LOG"
}

# Проверка зависимостей
check_dependencies() {
    local firewall_type=$(detect_firewall)
    
    case "$firewall_type" in
        "ufw")
            if ! command -v ufw >/dev/null 2>&1; then
                print_error "UFW не установлен"
                echo "💡 Установите: sudo apt install ufw"
                return 1
            fi
            ;;
        "iptables")
            if ! command -v iptables >/dev/null 2>&1; then
                print_error "iptables не найден"
                return 1
            fi
            ;;
        "firewalld")
            if ! command -v firewall-cmd >/dev/null 2>&1; then
                print_error "firewalld не установлен"
                echo "💡 Установите: sudo apt install firewalld"
                return 1
            fi
            ;;
        "none")
            print_error "Не найден поддерживаемый фаервол"
            echo "💡 Установите один из: UFW, iptables, firewalld"
            return 1
            ;;
    esac
    
    return 0
}

# Определение типа фаервола
detect_firewall() {
    if command -v ufw >/dev/null 2>&1 && systemctl is-active ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "none"
    fi
}

# Создание конфигурации
create_config() {
    cat > "$FIREWALL_CONFIG" << 'CONFIG_EOF'
# Конфигурация менеджера фаервола v2.0

# Автоматическое определение фаервола (ufw, iptables, firewalld)
AUTO_DETECT_FIREWALL=true

# Предпочтительный фаервол (если AUTO_DETECT_FIREWALL=false)
PREFERRED_FIREWALL="ufw"

# Настройки бэкапа
BACKUP_BEFORE_CHANGES=true
BACKUP_RETENTION_DAYS=7

# Стандартные порты для быстрого доступа
COMMON_PORTS=("22" "80" "443" "53" "21" "25" "110" "143" "993" "995")

# Зоны для firewalld
FIREWALLD_ZONES=("public" "internal" "trusted")

# Настройки логирования
LOG_DROPPED_PACKETS=true
LOG_LEVEL="low"

# Автоматические правила
AUTO_ALLOW_LOOPBACK=true
AUTO_ALLOW_SSH=true
AUTO_ALLOW_ICMP=true

# Политики по умолчанию
DEFAULT_INPUT_POLICY="DENY"
DEFAULT_OUTPUT_POLICY="ALLOW"
DEFAULT_FORWARD_POLICY="DENY"
CONFIG_EOF
    
    print_success "Конфигурация создана: $FIREWALL_CONFIG"
    log_action "CONFIG" "Создан конфигурационный файл" "INFO"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$FIREWALL_CONFIG" ]; then
        source "$FIREWALL_CONFIG"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        AUTO_DETECT_FIREWALL=true
        PREFERRED_FIREWALL="ufw"
        BACKUP_BEFORE_CHANGES=true
        BACKUP_RETENTION_DAYS=7
        COMMON_PORTS=("22" "80" "443" "53")
        FIREWALLD_ZONES=("public" "internal")
        LOG_DROPPED_PACKETS=true
        LOG_LEVEL="low"
        AUTO_ALLOW_LOOPBACK=true
        AUTO_ALLOW_SSH=true
        AUTO_ALLOW_ICMP=true
        DEFAULT_INPUT_POLICY="DENY"
        DEFAULT_OUTPUT_POLICY="ALLOW"
        DEFAULT_FORWARD_POLICY="DENY"
        
        log_action "CONFIG" "Используется конфигурация по умолчанию" "WARNING"
    fi
}

# Создание бэкапа правил
backup_rules() {
    local firewall_type=$(detect_firewall)
    local backup_file="$BACKUP_FILE"
    
    print_section "СОЗДАНИЕ БЭКАПА ПРАВИЛ"
    
    case "$firewall_type" in
        "ufw")
            if sudo ufw status numbered > "$backup_file" 2>/dev/null; then
                print_success "Бэкап UFW создан: $(basename "$backup_file")"
            else
                print_error "Не удалось создать бэкап UFW"
                return 1
            fi
            ;;
        "iptables")
            if sudo iptables-save > "$backup_file" 2>/dev/null; then
                print_success "Бэкап iptables создан: $(basename "$backup_file")"
            else
                print_error "Не удалось создать бэкап iptables"
                return 1
            fi
            ;;
        "firewalld")
            if sudo firewall-cmd --runtime-to-permanent 2>/dev/null && \
               sudo cp /etc/firewalld/firewalld.conf "$backup_file.firewalld.conf" 2>/dev/null; then
                print_success "Бэкап firewalld создан: $(basename "$backup_file")"
            else
                print_error "Не удалось создать бэкап firewalld"
                return 1
            fi
            ;;
        *)
            print_error "Неизвестный тип фаервола для бэкапа"
            return 1
            ;;
    esac
    
    log_action "BACKUP" "Создан бэкап правил: $backup_file" "INFO"
    echo "$backup_file"
}

# Восстановление из бэкапа
restore_rules() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        # Показываем доступные бэкапы
        print_section "ДОСТУПНЫЕ БЭКАПЫ"
        
        local backups=($(ls -1t "$BACKUP_DIR"/firewall-backup-*.rules 2>/dev/null | head -5))
        
        if [ ${#backups[@]} -eq 0 ]; then
            print_error "Бэкапы не найдены"
            return 1
        fi
        
        echo "Выберите бэкап для восстановления:"
        echo ""
        
        for i in "${!backups[@]}"; do
            local file=$(basename "${backups[$i]}")
            local date_part=$(echo "$file" | sed 's/firewall-backup-//' | sed 's/.rules//')
            local pretty_date=$(echo "$date_part" | sed 's/_/ /')
            echo "  $((i+1)). $pretty_date - $file"
        done
        
        echo ""
        read -p "Введите номер бэкапа: " backup_num
        
        if [[ ! "$backup_num" =~ ^[0-9]+$ ]] || [ "$backup_num" -lt 1 ] || [ "$backup_num" -gt ${#backups[@]} ]; then
            print_error "Некорректный номер бэкапа"
            return 1
        fi
        
        backup_file="${backups[$((backup_num-1))]}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    local firewall_type=$(detect_firewall)
    print_section "ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА"
    echo "  📁 Файл: $(basename "$backup_file")"
    echo "  🔧 Фаервол: $firewall_type"
    
    # Создаем бэкап текущего состояния
    backup_rules > /dev/null 2>&1
    
    case "$firewall_type" in
        "ufw")
            print_warning "Восстановление UFW требует ручного вмешательства"
            echo "  💡 Используйте: sudo ufw reset && cat $backup_file | sudo ufw import"
            ;;
        "iptables")
            if sudo iptables-restore < "$backup_file" 2>/dev/null; then
                print_success "Правила iptables восстановлены"
            else
                print_error "Ошибка восстановления iptables"
                return 1
            fi
            ;;
        "firewalld")
            if sudo firewall-cmd --reload 2>/dev/null; then
                print_success "Firewalld перезагружен"
            else
                print_error "Ошибка перезагрузки firewalld"
                return 1
            fi
            ;;
        *)
            print_error "Неизвестный тип фаервола для восстановления"
            return 1
            ;;
    esac
    
    log_action "RESTORE" "Восстановлены правила из $backup_file" "INFO"
}

# Расширенный статус фаервола
show_status_detailed() {
    local firewall_type=$(detect_firewall)
    
    print_section "ДЕТАЛЬНЫЙ СТАТУС ФАЕРВОЛА"
    echo "  🔧 Обнаружен фаервол: $firewall_type"
    echo ""
    
    case "$firewall_type" in
        "ufw")
            echo "📊 Статус UFW:"
            sudo ufw status verbose
            
            echo ""
            echo "📋 Нумерованные правила:"
            sudo ufw status numbered
            
            echo ""
            echo "📈 Статистика:"
            sudo ufw show raw | grep -c "DROP" 2>/dev/null | xargs echo "  🔻 Отброшено пакетов:"
            sudo ufw show raw | grep -c "ACCEPT" 2>/dev/null | xargs echo "  ✅ Принято пакетов:"
            ;;
            
        "iptables")
            echo "📊 Цепочки iptables:"
            echo "=== INPUT ЦЕПОЧКА ==="
            sudo iptables -L INPUT -n -v --line-numbers
            echo ""
            echo "=== OUTPUT ЦЕПОЧКА ==="
            sudo iptables -L OUTPUT -n -v --line-numbers
            echo ""
            echo "=== FORWARD ЦЕПОЧКА ==="
            sudo iptables -L FORWARD -n -v --line-numbers
            
            echo ""
            echo "📈 Статистика:"
            sudo iptables -L INPUT -n -v | awk '/^[[:space:]]*[0-9]+/ {pkts+=$1; bytes+=$2} END {print "  📦 Пакеты INPUT: " pkts " (" bytes " bytes)"}'
            sudo iptables -L OUTPUT -n -v | awk '/^[[:space:]]*[0-9]+/ {pkts+=$1; bytes+=$2} END {print "  📤 Пакеты OUTPUT: " pkts " (" bytes " bytes)"}'
            ;;
            
        "firewalld")
            echo "📊 Статус firewalld:"
            sudo firewall-cmd --state
            echo ""
            echo "🌍 Активная зона:"
            sudo firewall-cmd --get-active-zones
            echo ""
            echo "📋 Правила активной зоны:"
            sudo firewall-cmd --list-all
            echo ""
            echo "🛡️ Доступные сервисы:"
            sudo firewall-cmd --get-services | tr ' ' '\n' | head -10
            ;;
            
        *)
            print_error "Фаервол не активен или не поддерживается"
            echo "💡 Доступные фаерволы: UFW, iptables, firewalld"
            ;;
    esac
}

# Показать открытые порты системы
show_listening_ports() {
    print_section "ОТКРЫТЫЕ ПОРТЫ СИСТЕМЫ"
    
    echo "🔍 Слушающие порты:"
    if command -v ss >/dev/null 2>&1; then
        sudo ss -tulpn | head -20
    elif command -v netstat >/dev/null 2>&1; then
        sudo netstat -tulpn | head -20
    else
        echo "  ℹ️  ss или netstat не найдены"
    fi
    
    echo ""
    echo "🌐 Внешние подключения:"
    if command -v ss >/dev/null 2>&1; then
        sudo ss -tun | grep ESTAB | head -10
    fi
}

# Расширенный список правил
show_rules_detailed() {
    local firewall_type=$(detect_firewall)
    
    print_section "ДЕТАЛЬНЫЙ СПИСОК ПРАВИЛ"
    
    case "$firewall_type" in
        "ufw")
            echo "📋 Правила UFW:"
            sudo ufw status numbered
            
            echo ""
            echo "📊 Расширенная информация:"
            sudo ufw show added
            
            echo ""
            echo "🔄 Правила RAW:"
            sudo ufw show raw | head -20
            ;;
            
        "iptables")
            echo "📋 Все цепочки iptables:"
            for table in filter nat mangle raw; do
                if sudo iptables -t $table -L -n --line-numbers 2>/dev/null | grep -q -E "^Chain|^num"; then
                    echo "=== ТАБЛИЦА $table ==="
                    sudo iptables -t $table -L -n --line-numbers 2>/dev/null | head -20
                    echo ""
                fi
            done
            ;;
            
        "firewalld")
            echo "📋 Все зоны firewalld:"
            for zone in $(sudo firewall-cmd --get-zones); do
                echo "=== ЗОНА $zone ==="
                sudo firewall-cmd --zone="$zone" --list-all
                echo ""
            done
            ;;
            
        *)
            print_error "Фаервол не настроен"
            ;;
    esac
}

# Управление портами с расширенной функциональностью
manage_port() {
    local action=$1
    local port=$2
    local protocol=${3:-"tcp"}
    local source=${4:-""}
    
    if [ -z "$port" ]; then
        print_error "Укажите порт"
        return 1
    fi
    
    # Проверка валидности порта
    if [[ ! "$port" =~ ^[0-9]+(-[0-9]+)?$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "Некорректный порт: $port"
        return 1
    fi
    
    local firewall_type=$(detect_firewall)
    
    # Создаем бэкап перед изменениями
    if [ "$BACKUP_BEFORE_CHANGES" = "true" ]; then
        backup_rules > /dev/null 2>&1
    fi
    
    case "$firewall_type" in
        "ufw")
            case "$action" in
                "allow")
                    if [ -n "$source" ]; then
                        sudo ufw allow from "$source" to any port "$port"/"$protocol"
                    else
                        sudo ufw allow "$port"/"$protocol"
                    fi
                    print_success "Порт $port/$protocol разрешен"
                    ;;
                "deny")
                    if [ -n "$source" ]; then
                        sudo ufw deny from "$source" to any port "$port"/"$protocol"
                    else
                        sudo ufw deny "$port"/"$protocol"
                    fi
                    print_success "Порт $port/$protocol запрещен"
                    ;;
                "delete")
                    sudo ufw delete allow "$port"/"$protocol" 2>/dev/null || \
                    sudo ufw delete deny "$port"/"$protocol" 2>/dev/null || \
                    print_warning "Правило для порта $port не найдено"
                    print_success "Правило для порта $port удалено"
                    ;;
            esac
            ;;
            
        "iptables")
            case "$action" in
                "allow")
                    local rule="-A INPUT -p $protocol --dport $port -j ACCEPT"
                    if [ -n "$source" ]; then
                        rule="-A INPUT -s $source -p $protocol --dport $port -j ACCEPT"
                    fi
                    sudo iptables $rule
                    print_success "Правило добавлено: $rule"
                    ;;
                "deny")
                    local rule="-A INPUT -p $protocol --dport $port -j DROP"
                    if [ -n "$source" ]; then
                        rule="-A INPUT -s $source -p $protocol --dport $port -j DROP"
                    fi
                    sudo iptables $rule
                    print_success "Правило запрета добавлено: $rule"
                    ;;
                "delete")
                    # Находим номер правила и удаляем
                    local rule_num=$(sudo iptables -L INPUT --line-numbers -n | grep -E "dpt:$port($| )" | awk '{print $1}' | head -1)
                    if [ -n "$rule_num" ]; then
                        sudo iptables -D INPUT "$rule_num"
                        print_success "Правило $rule_num удалено"
                    else
                        print_warning "Правило для порта $port не найдено"
                    fi
                    ;;
            esac
            ;;
            
        "firewalld")
            case "$action" in
                "allow")
                    sudo firewall-cmd --add-port="$port/$protocol" --permanent
                    sudo firewall-cmd --reload
                    print_success "Порт $port/$protocol разрешен"
                    ;;
                "deny")
                    sudo firewall-cmd --remove-port="$port/$protocol" --permanent
                    sudo firewall-cmd --reload
                    print_success "Порт $port/$protocol запрещен"
                    ;;
                "delete")
                    sudo firewall-cmd --remove-port="$port/$protocol" --permanent
                    sudo firewall-cmd --reload
                    print_success "Правило для порта $port удалено"
                    ;;
            esac
            ;;
            
        *)
            print_error "Фаервол не настроен"
            return 1
            ;;
    esac
    
    log_action "${action^^}_PORT" "Порт $port/$protocol $action (source: ${source:-any})" "INFO"
}

# Управление сервисами
manage_service() {
    local action=$1
    local service=$2
    
    if [ -z "$service" ]; then
        print_error "Укажите имя сервиса"
        return 1
    fi
    
    local firewall_type=$(detect_firewall)
    
    case "$firewall_type" in
        "ufw")
            case "$action" in
                "allow")
                    sudo ufw allow "$service"
                    print_success "Сервис $service разрешен"
                    ;;
                "deny")
                    sudo ufw deny "$service"
                    print_success "Сервис $service запрещен"
                    ;;
            esac
            ;;
            
        "firewalld")
            case "$action" in
                "allow")
                    sudo firewall-cmd --add-service="$service" --permanent
                    sudo firewall-cmd --reload
                    print_success "Сервис $service разрешен"
                    ;;
                "deny")
                    sudo firewall-cmd --remove-service="$service" --permanent
                    sudo firewall-cmd --reload
                    print_success "Сервис $service запрещен"
                    ;;
            esac
            ;;
            
        *)
            print_error "Управление сервисами поддерживается только в UFW и firewalld"
            return 1
            ;;
    esac
    
    log_action "${action^^}_SERVICE" "Сервис $service $action" "INFO"
}

# Включение/выключение фаервола
manage_firewall_state() {
    local action=$1
    
    local firewall_type=$(detect_firewall)
    
    case "$firewall_type" in
        "ufw")
            case "$action" in
                "enable")
                    sudo ufw --force enable
                    print_success "Фаервол UFW включен"
                    ;;
                "disable")
                    sudo ufw disable
                    print_success "Фаервол UFW выключен"
                    ;;
            esac
            ;;
            
        "iptables")
            case "$action" in
                "enable")
                    print_warning "Для iptables включите сохранение правил:"
                    echo "  sudo iptables-save > /etc/iptables/rules.v4"
                    echo "  sudo ip6tables-save > /etc/iptables/rules.v6"
                    ;;
                "disable")
                    sudo iptables -F
                    sudo iptables -X
                    sudo iptables -P INPUT ACCEPT
                    sudo iptables -P FORWARD ACCEPT
                    sudo iptables -P OUTPUT ACCEPT
                    print_success "Правила iptables очищены"
                    ;;
            esac
            ;;
            
        "firewalld")
            case "$action" in
                "enable")
                    sudo systemctl enable firewalld
                    sudo systemctl start firewalld
                    print_success "Фаервол firewalld включен"
                    ;;
                "disable")
                    sudo systemctl stop firewalld
                    sudo systemctl disable firewalld
                    print_success "Фаервол firewalld выключен"
                    ;;
            esac
            ;;
            
        *)
            print_error "Фаервол не настроен"
            return 1
            ;;
    esac
    
    log_action "${action^^}_FIREWALL" "Фаервол $action" "INFO"
}

# Сброс правил
reset_rules_advanced() {
    local firewall_type=$(detect_firewall)
    
    print_section "СБРОС ПРАВИЛ ФАЕРВОЛА"
    echo "  🔧 Фаервол: $firewall_type"
    
    # Создаем бэкап перед сбросом
    local backup_file=$(backup_rules)
    
    case "$firewall_type" in
        "ufw")
            sudo ufw --force reset
            print_success "Правила UFW сброшены"
            ;;
        "iptables")
            sudo iptables -F
            sudo iptables -X
            sudo iptables -t nat -F
            sudo iptables -t nat -X
            sudo iptables -t mangle -F
            sudo iptables -t mangle -X
            sudo iptables -P INPUT ACCEPT
            sudo iptables -P FORWARD ACCEPT
            sudo iptables -P OUTPUT ACCEPT
            print_success "Правила iptables сброшены"
            ;;
        "firewalld")
            sudo firewall-cmd --complete-reload
            print_success "Firewalld перезагружен"
            ;;
        *)
            print_error "Фаервол не настроен"
            return 1
            ;;
    esac
    
    print_warning "Создан бэкап перед сбросом: $(basename "$backup_file")"
    log_action "RESET" "Правила фаервола сброшены (бэкап: $backup_file)" "WARNING"
}

# Быстрая настройка common портов
setup_common_ports() {
    print_section "БЫСТРАЯ НАСТРОЙКА ОБЩИХ ПОРТОВ"
    
    echo "🔧 Настройка портов: ${COMMON_PORTS[*]}"
    echo ""
    
    for port in "${COMMON_PORTS[@]}"; do
        echo "  🔄 Настройка порта $port..."
        manage_port "allow" "$port" "tcp"
    done
    
    print_success "Общие порты настроены"
    log_action "SETUP_COMMON_PORTS" "Настроены порты: ${COMMON_PORTS[*]}" "INFO"
}

# Анализ безопасности
security_analysis() {
    print_section "АНАЛИЗ БЕЗОПАСНОСТИ"
    
    local firewall_type=$(detect_firewall)
    
    echo "🔍 Проверка конфигурации фаервола..."
    echo ""
    
    case "$firewall_type" in
        "ufw")
            local status=$(sudo ufw status 2>/dev/null | grep -i "status" | awk '{print $2}')
            if [ "$status" = "active" ]; then
                print_success "UFW активен"
            else
                print_error "UFW не активен"
            fi
            
            # Проверка политик по умолчанию
            local input_policy=$(sudo ufw status verbose | grep "Default:" | awk '{print $2}')
            local output_policy=$(sudo ufw status verbose | grep "Default:" | awk '{print $3}')
            
            if [ "$input_policy" = "deny" ]; then
                print_success "Входящая политика: $input_policy"
            else
                print_warning "Входящая политика: $input_policy (рекомендуется: deny)"
            fi
            ;;
            
        "iptables")
            # Проверка базовых цепочек
            local input_policy=$(sudo iptables -L INPUT -n | grep "policy" | awk '{print $4}' | tr -d ')')
            if [ "$input_policy" = "DROP" ] || [ "$input_policy" = "REJECT" ]; then
                print_success "INPUT политика: $input_policy"
            else
                print_warning "INPUT политика: $input_policy (рекомендуется: DROP)"
            fi
            ;;
            
        *)
            print_warning "Анализ безопасности для $firewall_type не реализован"
            ;;
    esac
    
    # Проверка открытых портов
    echo ""
    echo "🔓 Проверка открытых портов:"
    show_listening_ports
}

# Мониторинг в реальном времени
monitor_traffic() {
    print_section "МОНИТОРИНГ СЕТЕВОГО ТРАФИКА"
    
    echo "📈 Мониторинг сетевой активности..."
    echo "⏹️  Нажмите Ctrl+C для остановки"
    echo ""
    
    if command -v iptables >/dev/null 2>&1; then
        # Сбрасываем счетчики
        sudo iptables -Z
        
        echo "🔄 Счетчики пакетов (обновление каждые 2 секунды):"
        echo ""
        
        local counter=0
        while true; do
            counter=$((counter + 1))
            clear
            print_header
            echo "🔁 Цикл мониторинга: $counter"
            echo "⏰ Время: $(date)"
            echo "=========================================="
            
            echo "📊 СТАТИСТИКА ПАКЕТОВ:"
            sudo iptables -L INPUT -n -v | head -10
            echo ""
            echo "🔍 ПОСЛЕДНИЕ СОБЫТИЯ:"
            sudo dmesg | grep -i "firewall\|iptables" | tail -5
            
            echo ""
            echo "⏳ Следующее обновление через 2 секунды..."
            sleep 2
        done
    else
        print_error "iptables не найден для мониторинга"
    fi
}

# Основная функция
main() {
    load_config
    
    if ! check_dependencies; then
        exit 1
    fi
    
    case "${1:-}" in
        "status")
            print_header
            show_status_detailed
            ;;
        "list")
            print_header
            show_rules_detailed
            ;;
        "allow")
            print_header
            manage_port "allow" "$2" "$3" "$4"
            ;;
        "deny")
            print_header
            manage_port "deny" "$2" "$3" "$4"
            ;;
        "delete")
            print_header
            manage_port "delete" "$2" "$3"
            ;;
        "allow-service")
            print_header
            manage_service "allow" "$2"
            ;;
        "deny-service")
            print_header
            manage_service "deny" "$2"
            ;;
        "enable")
            print_header
            manage_firewall_state "enable"
            ;;
        "disable")
            print_header
            manage_firewall_state "disable"
            ;;
        "reset")
            print_header
            reset_rules_advanced
            ;;
        "backup")
            print_header
            backup_rules
            ;;
        "restore")
            print_header
            restore_rules "$2"
            ;;
        "ports")
            print_header
            show_listening_ports
            ;;
        "setup-common")
            print_header
            setup_common_ports
            ;;
        "security")
            print_header
            security_analysis
            ;;
        "monitor")
            print_header
            monitor_traffic
            ;;
        "config")
            print_header
            create_config
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

# Функция показа справки
show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА] [ОПЦИИ]"
    echo ""
    echo "Основные команды:"
    echo "  status                    - Детальный статус фаервола"
    echo "  list                      - Детальный список правил"
    echo "  allow <port> [proto] [src]- Разрешить порт"
    echo "  deny <port> [proto] [src] - Запретить порт"
    echo "  delete <port> [proto]     - Удалить правило порта"
    echo "  allow-service <service>   - Разрешить сервис"
    echo "  deny-service <service>    - Запретить сервис"
    echo ""
    echo "Управление состоянием:"
    echo "  enable                    - Включить фаервол"
    echo "  disable                   - Выключить фаервол"
    echo "  reset                     - Сбросить правила (с бэкапом)"
    echo "  backup                    - Создать бэкап правил"
    echo "  restore [file]            - Восстановить из бэкапа"
    echo ""
    echo "Дополнительные команды:"
    echo "  ports                     - Показать открытые порты системы"
    echo "  setup-common              - Быстрая настройка общих портов"
    echo "  security                  - Анализ безопасности"
    echo "  monitor                   - Мониторинг трафика в реальном времени"
    echo "  config                    - Создать конфигурационный файл"
    echo "  help                      - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 status                    # Детальный статус"
    echo "  $0 allow 22                  # Разрешить SSH"
    echo "  $0 allow 80 tcp              # Разрешить HTTP"
    echo "  $0 allow 443 tcp 192.168.1.0/24 # Разрешить с подсети"
    echo "  $0 allow-service ssh         # Разрешить сервис SSH"
    echo "  $0 setup-common              # Настроить общие порты"
    echo "  $0 monitor                   # Мониторинг трафика"
    echo "  $0 restore                   # Восстановить из бэкапа"
}

main "$@"
