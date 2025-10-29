#!/bin/bash
# 🔒 Продвинутая система аудита безопасности с аналитикой уязвимостей
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORTS_DIR="$PROJECT_ROOT/reports"
CACHE_DIR="$PROJECT_ROOT/cache"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$CACHE_DIR"

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
CONFIG_FILE="$CONFIG_DIR/security-audit.conf"
MAIN_LOG="$LOG_DIR/security-audit.log"
CACHE_FILE="$CACHE_DIR/security-cache.db"
SCORE_FILE="$CACHE_DIR/security-score.txt"
VULNERABILITY_DB="$CONFIG_DIR/vulnerability-patterns.conf"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🔒 ==========================================="
    echo "   ПРОДВИНУТЫЙ АУДИТ БЕЗОПАСНОСТИ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}🔍 $1${NC}"
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

print_critical() {
    echo -e "${RED}🚨 $1${NC}"
}

# Логирование
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
}

# Система оценки безопасности
SECURITY_SCORE=100
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0

deduct_score() {
    local points=$1
    local level=$2
    local message=$3
    
    SECURITY_SCORE=$((SECURITY_SCORE - points))
    
    case $level in
        "CRITICAL")
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            print_critical "$message (-$points)"
            ;;
        "HIGH")
            HIGH_ISSUES=$((HIGH_ISSUES + 1))
            print_error "$message (-$points)"
            ;;
        "MEDIUM")
            MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
            print_warning "$message (-$points)"
            ;;
        "LOW")
            LOW_ISSUES=$((LOW_ISSUES + 1))
            print_info "$message (-$points)"
            ;;
    esac
}

# Создание конфигурации
create_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Конфигурация аудита безопасности v2.0

# Основные настройки
ENABLE_DEEP_SCAN=true
ENABLE_NETWORK_SCAN=true
ENABLE_FILE_INTEGRITY_CHECK=false
ENABLE_MALWARE_SCAN=false
SAVE_DETAILED_REPORTS=true
REPORT_RETENTION_DAYS=30

# Настройки сканирования
SCAN_USER_ACCOUNTS=true
SCAN_SERVICES=true
SCAN_NETWORK=true
SCAN_FILESYSTEM=true
SCAN_KERNEL=true
SCAN_LOGS=true

# Пороговые значения
PASSWORD_MAX_DAYS=90
MIN_PASSWORD_LENGTH=8
SSH_PORT=22
ALLOW_ROOT_LOGIN=false
ALLOW_PASSWORD_AUTH=false

# Настройки безопасности
CHECK_SUID_FILES=true
CHECK_WRITABLE_DIRS=true
CHECK_HIDDEN_PROCESSES=true
CHECK_CRON_JOBS=true
CHECK_SERVICE_PERMISSIONS=true

# Настройки сети
CHECK_OPEN_PORTS=true
CHECK_LISTENING_SERVICES=true
CHECK_FIREWALL_STATUS=true
CHECK_NETWORK_HARDENING=true

# Настройки производительности
ENABLE_CACHING=true
CACHE_TTL=3600
MAX_LOG_SIZE=10485760

# Дополнительные проверки
CHECK_DOCKER_SECURITY=false
CHECK_WEB_SERVERS=true
CHECK_DATABASE_SECURITY=true
CHECK_SSL_CONFIGURATION=true

# Настройки отчетов
GENERATE_HTML_REPORT=false
SHOW_RECOMMENDATIONS=true
CALCULATE_SECURITY_SCORE=true
EXPORT_RESULTS=true
EOF

    # База данных уязвимостей
    cat > "$VULNERABILITY_DB" << 'EOF'
# Паттерны уязвимостей и подозрительной активности

# Критические уязвимости
CRITICAL_PATTERNS=(
    "password.*null"
    "root.*ALL.*NOPASSWD"
    "PermitRootLogin.*yes"
    "PasswordAuthentication.*yes"
    "Protocol.*1"
)

# Подозрительные файлы и директории
SUSPICIOUS_PATHS=(
    "/tmp/.*\.sh"
    "/var/tmp/.*\.elf"
    "/dev/shm/.*"
    ".*\.miner"
    ".*cryptocurrency.*"
)

# Подозрительные процессы
SUSPICIOUS_PROCESSES=(
    "minerd"
    "cpuminer"
    "xmrig"
    "sqlmap"
    "john"
    "hydra"
    "nmap"
)

# Уязвимые версии ПО
VULNERABLE_VERSIONS=(
    "openssh.*7\.[0-5]"
    "nginx.*1\.[0-9]\.[0-9]"
    "apache.*2\.[0-3]"
    "mysql.*5\.[0-6]"
    "php.*5\.[0-9]"
)

# Небезопасные настройки ядра
INSECURE_KERNEL_SETTINGS=(
    "net.ipv4.ip_forward=1"
    "kernel.dmesg_restrict=0"
    "kernel.kptr_restrict=0"
    "net.ipv4.conf.all.accept_redirects=1"
)
EOF

    print_success "Конфигурационные файлы созданы:"
    print_success "  $CONFIG_FILE"
    print_success "  $VULNERABILITY_DB"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        ENABLE_DEEP_SCAN=true
        SCAN_USER_ACCOUNTS=true
        SCAN_SERVICES=true
        SCAN_NETWORK=true
        PASSWORD_MAX_DAYS=90
        MIN_PASSWORD_LENGTH=8
        ALLOW_ROOT_LOGIN=false
        ALLOW_PASSWORD_AUTH=false
        ENABLE_CACHING=true
        CACHE_TTL=3600
    fi

    if [ -f "$VULNERABILITY_DB" ]; then
        source "$VULNERABILITY_DB"
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in grep awk sed head tail ps; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты для расширенных функций
    if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
        optional_missing+=("net-tools")
    fi
    
    if ! command -v lsof &> /dev/null; then
        optional_missing+=("lsof")
    fi
    
    if [ "$ENABLE_MALWARE_SCAN" = "true" ] && ! command -v clamscan &> /dev/null; then
        optional_missing+=("clamav")
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

# Проверка обновлений системы
check_system_updates() {
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ СИСТЕМЫ"
    
    local updates_available=0
    local security_updates=0
    
    if command -v apt-get &> /dev/null; then
        echo "  🔄 Проверка обновлений APT..."
        if ! sudo apt update > /dev/null 2>&1; then
            deduct_score 5 "MEDIUM" "Не удалось обновить список пакетов APT"
            return
        fi
        
        updates_available=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        if [ "$updates_available" -gt 1 ]; then
            updates_available=$((updates_available - 1))
            security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
            
            deduct_score $((updates_available * 2)) "HIGH" "Доступно обновлений: $updates_available (безопасность: $security_updates)"
            
            if [ "$security_updates" -gt 0 ]; then
                echo "  📋 Критические обновления безопасности:"
                apt list --upgradable 2>/dev/null | grep -i security | head -5 | while read -r pkg; do
                    echo "    🚨 $pkg"
                done
            fi
        else
            print_success "Система полностью обновлена"
        fi
    else
        print_warning "Менеджер пакетов APT не найден"
    fi
}

# Расширенная проверка парольной политики
check_password_policy() {
    if [ "$SCAN_USER_ACCOUNTS" != "true" ]; then
        return
    fi
    
    print_section "РАСШИРЕННАЯ ПРОВЕРКА ПАРОЛЬНОЙ ПОЛИТИКИ"
    
    local issues_found=0
    
    # Проверка /etc/login.defs
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_warn_age=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_min_len=$(grep "^PASS_MIN_LEN" /etc/login.defs | awk '{print $2}' | head -1)
        
        echo "  📋 Текущая политика паролей:"
        echo "    🔐 Макс. дней пароля: ${pass_max_days:-Не установлено}"
        echo "    🔐 Мин. дней пароля: ${pass_min_days:-Не установлено}"
        echo "    🔐 Предупреждение за дней: ${pass_warn_age:-Не установлено}"
        echo "    🔐 Мин. длина пароля: ${pass_min_len:-Не установлено}"
        
        # Проверка максимального возраста пароля
        if [ -n "$pass_max_days" ] && [ "$pass_max_days" -gt "$PASSWORD_MAX_DAYS" ]; then
            deduct_score 10 "HIGH" "Слишком долгий срок жизни пароля ($pass_max_days > $PASSWORD_MAX_DAYS)"
            issues_found=$((issues_found + 1))
        fi
        
        # Проверка минимальной длины пароля
        if [ -z "$pass_min_len" ] || [ "$pass_min_len" -lt "$MIN_PASSWORD_LENGTH" ]; then
            deduct_score 5 "MEDIUM" "Слишком короткая минимальная длина пароля"
            issues_found=$((issues_found + 1))
        fi
    else
        deduct_score 15 "HIGH" "Файл login.defs не найден"
        issues_found=$((issues_found + 1))
    fi
    
    # Проверка пользователей с паролями
    echo ""
    echo "  👥 Проверка пользователей:"
    
    if [ -f /etc/shadow ] && [ -r /etc/shadow ]; then
        local empty_password_users=$(awk -F: '($2 == "" || $2 == "!" || $2 == "*") {print $1}' /etc/shadow 2>/dev/null | wc -l)
        local expired_password_users=$(awk -F: '($2 != "" && $2 != "!" && $2 != "*") {print $1}' /etc/shadow 2>/dev/null | while read user; do
            chage -l "$user" 2>/dev/null | grep -q "Password expired" && echo "$user"
        done | wc -l)
        
        if [ "$empty_password_users" -gt 0 ]; then
            deduct_score 20 "CRITICAL" "Обнаружены пользователи с пустыми паролями: $empty_password_users"
            issues_found=$((issues_found + 1))
        fi
        
        if [ "$expired_password_users" -gt 0 ]; then
            deduct_score 10 "HIGH" "Обнаружены пользователи с просроченными паролями: $expired_password_users"
            issues_found=$((issues_found + 1))
        fi
        
        print_success "Пользователи с пустыми паролями: $empty_password_users"
        print_success "Пользователи с просроченными паролями: $expired_password_users"
    else
        deduct_score 10 "MEDIUM" "Не удалось прочитать /etc/shadow"
        issues_found=$((issues_found + 1))
    fi
    
    if [ "$issues_found" -eq 0 ]; then
        print_success "Парольная политика соответствует стандартам"
    fi
}

# Улучшенная проверка SSH безопасности
check_ssh_security() {
    print_section "УГЛУБЛЕННАЯ ПРОВЕРКА SSH БЕЗОПАСНОСТИ"
    
    local sshd_config_locations=(
        "/etc/ssh/sshd_config"
        "/etc/sshd_config"
        "/usr/local/etc/ssh/sshd_config"
    )
    
    local sshd_config_found=""
    local ssh_issues=0
    
    for config in "${sshd_config_locations[@]}"; do
        if [ -f "$config" ]; then
            sshd_config_found="$config"
            break
        fi
    done
    
    if [ -n "$sshd_config_found" ]; then
        echo "  📁 Файл конфигурации: $sshd_config_found"
        
        # Чтение параметров SSH
        local permit_root=$(grep -i "^PermitRootLogin" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ' | tr -d '#')
        local password_auth=$(grep -i "^PasswordAuthentication" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ' | tr -d '#')
        local protocol=$(grep -i "^Protocol" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ' | tr -d '#')
        local port=$(grep -i "^Port" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ' | tr -d '#')
        local max_auth_tries=$(grep -i "^MaxAuthTries" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ' | tr -d '#')
        
        echo "  ⚙️  Параметры SSH:"
        echo "    🔑 Root доступ: ${permit_root:-yes}"
        echo "    🔑 Аутентификация паролем: ${password_auth:-yes}"
        echo "    🌐 Протокол: ${protocol:-2}"
        echo "    🚪 Порт: ${port:-22}"
        echo "    🔐 Макс. попыток аутентификации: ${max_auth_tries:-6}"
        
        # Проверка параметров
        if [ "${permit_root:-yes}" = "yes" ] && [ "$ALLOW_ROOT_LOGIN" = "false" ]; then
            deduct_score 15 "CRITICAL" "Root доступ по SSH разрешен"
            ssh_issues=$((ssh_issues + 1))
        fi
        
        if [ "${password_auth:-yes}" = "yes" ] && [ "$ALLOW_PASSWORD_AUTH" = "false" ]; then
            deduct_score 10 "HIGH" "Аутентификация паролем разрешена"
            ssh_issues=$((ssh_issues + 1))
        fi
        
        if [ "${protocol:-2}" != "2" ]; then
            deduct_score 20 "CRITICAL" "Устаревшая версия протокола SSH: $protocol"
            ssh_issues=$((ssh_issues + 1))
        fi
        
        if [ "${port:-22}" = "22" ]; then
            deduct_score 5 "MEDIUM" "SSH работает на стандартном порту 22"
            ssh_issues=$((ssh_issues + 1))
        fi
        
        if [ "${max_auth_tries:-6}" -gt 3 ]; then
            deduct_score 3 "LOW" "Слишком много попыток аутентификации: $max_auth_tries"
            ssh_issues=$((ssh_issues + 1))
        fi
        
        # Проверка версии SSH
        if command -v sshd &> /dev/null; then
            local sshd_version=$(sshd -V 2>&1 | head -1 | grep -o '[0-9]\.[0-9]' | head -1)
            echo "    📦 Версия SSH: ${sshd_version:-неизвестно}"
            
            if [ -n "$sshd_version" ] && [ "${sshd_version%%.*}" -lt "7" ]; then
                deduct_score 10 "HIGH" "Устаревшая версия SSH: $sshd_version"
                ssh_issues=$((ssh_issues + 1))
            fi
        fi
        
    else
        deduct_score 5 "MEDIUM" "SSH сервер не установлен или конфиг не найден"
        ssh_issues=$((ssh_issues + 1))
    fi
    
    # Проверка активных SSH сессий
    echo ""
    echo "  🔍 Активные SSH сессии:"
    local active_sessions=$(who | grep -c pts)
    local failed_attempts=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
    
    echo "    💻 Активные сессии: $active_sessions"
    echo "    🚫 Неудачных попыток: $failed_attempts"
    
    if [ "$failed_attempts" -gt 100 ]; then
        deduct_score 10 "HIGH" "Много неудачных попыток входа: $failed_attempts"
        ssh_issues=$((ssh_issues + 1))
    fi
    
    if [ "$ssh_issues" -eq 0 ]; then
        print_success "SSH конфигурация безопасна"
    fi
}

# Расширенная проверка открытых портов
check_open_ports() {
    if [ "$SCAN_NETWORK" != "true" ]; then
        return
    fi
    
    print_section "РАСШИРЕННАЯ ПРОВЕРКА СЕТЕВЫХ ПОРТОВ"
    
    local open_ports=0
    local suspicious_ports=0
    
    # Список подозрительных портов
    local dangerous_ports=("23" "135" "137" "138" "139" "445" "1433" "1434" "3306" "5432" "5900" "3389")
    
    if command -v ss &> /dev/null; then
        echo "  🌐 Слушающие порты (ss):"
        ss -tulpn 2>/dev/null | grep LISTEN | while read -r line; do
            local port=$(echo "$line" | awk '{print $5}' | rev | cut -d: -f1 | rev)
            local protocol=$(echo "$line" | awk '{print $1}')
            local service=$(echo "$line" | awk '{print $7}' | cut -d'"' -f2)
            
            if [ -n "$port" ] && [ "$port" != "Address" ]; then
                open_ports=$((open_ports + 1))
                local port_status="    📍 $protocol порт $port: ${service:-unknown}"
                
                # Проверка на подозрительные порты
                if [[ " ${dangerous_ports[@]} " =~ " ${port} " ]]; then
                    port_status="$port_status ⚠️"
                    suspicious_ports=$((suspicious_ports + 1))
                    deduct_score 5 "MEDIUM" "Подозрительный открытый порт: $port ($service)"
                fi
                
                echo "$port_status"
            fi
        done
    elif command -v netstat &> /dev/null; then
        echo "  🌐 Слушающие порты (netstat):"
        netstat -tulpn 2>/dev/null | grep LISTEN | while read -r line; do
            local port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
            local protocol=$(echo "$line" | awk '{print $1}')
            local service=$(echo "$line" | awk '{print $7}')
            
            if [ -n "$port" ] && [ "$port" != "Address" ]; then
                open_ports=$((open_ports + 1))
                local port_status="    📍 $protocol порт $port: ${service:-unknown}"
                
                if [[ " ${dangerous_ports[@]} " =~ " ${port} " ]]; then
                    port_status="$port_status ⚠️"
                    suspicious_ports=$((suspicious_ports + 1))
                    deduct_score 5 "MEDIUM" "Подозрительный открытый порт: $port ($service)"
                fi
                
                echo "$port_status"
            fi
        done
    else
        deduct_score 5 "MEDIUM" "Команды ss/netstat не найдены"
    fi
    
    echo ""
    echo "  📊 Статистика портов:"
    echo "    🟢 Всего открытых портов: $open_ports"
    echo "    🟡 Подозрительных портов: $suspicious_ports"
    
    if [ "$open_ports" -gt 50 ]; then
        deduct_score 5 "MEDIUM" "Слишком много открытых портов: $open_ports"
    fi
}

# Улучшенная проверка SUID/GUID файлов
check_suid_files() {
    if [ "$CHECK_SUID_FILES" != "true" ]; then
        return
    fi
    
    print_section "ПРОВЕРКА SUID/GUID ФАЙЛОВ"
    
    echo "  🔍 Поиск SUID/GUID файлов (может занять время)..."
    
    local suid_files=$(find / -type f -perm -4000 2>/dev/null | grep -v "^/proc" | grep -v "^/sys" | grep -v "^/dev" | grep -v "^/run" | wc -l)
    local guid_files=$(find / -type f -perm -2000 2>/dev/null | grep -v "^/proc" | grep -v "^/sys" | grep -v "^/dev" | grep -v "^/run" | wc -l)
    
    echo "  📊 Найдено SUID файлов: $suid_files"
    echo "  📊 Найдено GUID файлов: $guid_files"
    
    # Проверка необычных SUID файлов
    local unusual_suid=$(find / -type f -perm -4000 2>/dev/null | \
        grep -v "^/bin" | \
        grep -v "^/sbin" | \
        grep -v "^/usr/bin" | \
        grep -v "^/usr/sbin" | \
        grep -v "^/usr/local/bin" | \
        wc -l)
    
    if [ "$unusual_suid" -gt 0 ]; then
        deduct_score 15 "HIGH" "Обнаружены необычные SUID файлы: $unusual_suid"
        echo "  🚨 Необычные SUID файлы:"
        find / -type f -perm -4000 2>/dev/null | \
            grep -v "^/bin" | \
            grep -v "^/sbin" | \
            grep -v "^/usr/bin" | \
            grep -v "^/usr/sbin" | \
            grep -v "^/usr/local/bin" | \
            head -10 | while read -r file; do
                echo "    ❗ $file"
            done
    fi
    
    if [ "$suid_files" -gt 100 ]; then
        deduct_score 10 "MEDIUM" "Много SUID файлов: $suid_files"
    elif [ "$suid_files" -eq 0 ]; then
        print_success "SUID файлы не найдены"
    else
        print_success "Количество SUID файлов в норме"
    fi
}

# Проверка файрвола
check_firewall() {
    if [ "$CHECK_FIREWALL_STATUS" != "true" ]; then
        return
    fi
    
    print_section "ПРОВЕРКА СИСТЕМЫ ФАЙРВОЛА"
    
    local firewall_active=0
    local firewall_rules=0
    
    # Проверка UFW
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            firewall_active=1
            firewall_rules=$(ufw status numbered 2>/dev/null | grep -c "^\[" || echo 0)
            print_success "UFW включен ($firewall_rules правил)"
        else
            deduct_score 15 "HIGH" "UFW отключен"
        fi
    fi
    
    # Проверка iptables
    if command -v iptables &> /dev/null; then
        local iptables_rules=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo 0)
        if iptables -L INPUT 2>/dev/null | grep -q "policy DROP"; then
            if [ "$firewall_active" -eq 0 ]; then
                firewall_active=1
            fi
            firewall_rules=$((firewall_rules + iptables_rules))
            print_success "IPTables настроен ($iptables_rules правил)"
        else
            if [ "$firewall_active" -eq 0 ]; then
                deduct_score 20 "CRITICAL" "Файрвол не настроен (IPTables политика не DROP)"
            fi
        fi
    fi
    
    # Проверка firewalld
    if command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            firewall_active=1
            print_success "Firewalld активен"
        else
            if [ "$firewall_active" -eq 0 ]; then
                deduct_score 15 "HIGH" "Firewalld не активен"
            fi
        fi
    fi
    
    if [ "$firewall_active" -eq 0 ]; then
        deduct_score 25 "CRITICAL" "Активный файрвол не обнаружен"
    fi
    
    echo "  📊 Статус файрвола:"
    echo "    🛡️  Активный файрвол: $( [ "$firewall_active" -eq 1 ] && echo "Да" || echo "Нет" )"
    echo "    📋 Всего правил: $firewall_rules"
}

# Расширенная проверка настроек ядра
check_kernel_security() {
    if [ "$SCAN_KERNEL" != "true" ]; then
        return
    fi
    
    print_section "ПРОВЕРКА НАСТРОЕК БЕЗОПАСНОСТИ ЯДРА"
    
    local kernel_checks=(
        "net.ipv4.ip_forward:0:MEDIUM:10"
        "kernel.dmesg_restrict:1:HIGH:15"
        "kernel.kptr_restrict:2:HIGH:15"
        "net.ipv4.conf.all.accept_redirects:0:MEDIUM:10"
        "net.ipv4.conf.all.send_redirects:0:MEDIUM:10"
        "net.ipv4.icmp_echo_ignore_broadcasts:1:MEDIUM:5"
        "net.ipv4.icmp_ignore_bogus_error_responses:1:MEDIUM:5"
        "net.ipv4.conf.all.rp_filter:1:MEDIUM:10"
        "net.ipv4.tcp_syncookies:1:HIGH:15"
        "kernel.yama.ptrace_scope:1:HIGH:15"
    )
    
    local secure_count=0
    local total_checks=${#kernel_checks[@]}
    
    echo "  ⚙️  Проверка параметров ядра:"
    
    for check in "${kernel_checks[@]}"; do
        IFS=':' read -r key expected level points <<< "$check"
        local actual
        
        if actual=$(sysctl -n "$key" 2>/dev/null); then
            if [ "$actual" = "$expected" ]; then
                echo "    ✅ $key = $actual"
                secure_count=$((secure_count + 1))
            else
                echo "    ❌ $key = $actual (ожидается: $expected)"
                deduct_score "$points" "$level" "Небезопасная настройка ядра: $key = $actual"
            fi
        else
            echo "    ❓ $key: недоступно"
            deduct_score 5 "LOW" "Параметр ядра недоступен: $key"
        fi
    done
    
    local security_percent=$((secure_count * 100 / total_checks))
    echo ""
    echo "  📊 Безопасность ядра: $security_percent% ($secure_count/$total_checks)"
    
    if [ "$security_percent" -ge 80 ]; then
        print_success "Настройки ядра в основном безопасны"
    elif [ "$security_percent" -ge 60 ]; then
        print_warning "Некоторые настройки ядра требуют внимания"
    else
        print_error "Многие настройки ядра небезопасны"
    fi
}

# Проверка подозрительных процессов
check_suspicious_processes() {
    if [ "$CHECK_HIDDEN_PROCESSES" != "true" ]; then
        return
    fi
    
    print_section "ПОИСК ПОДОЗРИТЕЛЬНЫХ ПРОЦЕССОВ"
    
    local suspicious_found=0
    
    echo "  🔍 Сканирование процессов на подозрительную активность..."
    
    for pattern in "${SUSPICIOUS_PROCESSES[@]}"; do
        local count=$(ps aux | grep -c "$pattern" | grep -v grep || true)
        if [ "$count" -gt 0 ]; then
            deduct_score 20 "CRITICAL" "Обнаружен подозрительный процесс: $pattern"
            suspicious_found=$((suspicious_found + 1))
            echo "    🚨 Найден: $pattern"
        fi
    done
    
    # Поиск скрытых процессов
    local hidden_processes=$(ps -eo pid,comm | grep -v "\[\|]$" | awk '{print $1}' | while read pid; do
        if [ ! -d "/proc/$pid" ]; then
            echo "$pid"
        fi
    done | wc -l)
    
    if [ "$hidden_processes" -gt 0 ]; then
        deduct_score 25 "CRITICAL" "Обнаружены скрытые процессы: $hidden_processes"
        suspicious_found=$((suspicious_found + 1))
    fi
    
    if [ "$suspicious_found" -eq 0 ]; then
        print_success "Подозрительные процессы не обнаружены"
    else
        echo "  📊 Найдено подозрительных процессов: $suspicious_found"
    fi
}

# Проверка cron задач
check_cron_jobs() {
    if [ "$CHECK_CRON_JOBS" != "true" ]; then
        return
    fi
    
    print_section "ПРОВЕРКА CRON ЗАДАЧ"
    
    local suspicious_cron=0
    
    echo "  ⏰ Проверка системных cron задач..."
    
    # Проверка системного crontab
    if [ -f /etc/crontab ]; then
        local cron_jobs=$(grep -v "^#" /etc/crontab | grep -v "^$" | wc -l)
        echo "    📋 Системных cron задач: $cron_jobs"
    fi
    
    # Проверка cron директорий
    local cron_dirs=("/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")
    for dir in "${cron_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local files_count=$(find "$dir" -type f | wc -l)
            echo "    📁 $dir: $files_count файлов"
        fi
    done
    
    # Поиск подозрительных cron задач
    echo "  🔍 Поиск подозрительных cron задач..."
    find /etc/cron* -type f 2>/dev/null | while read -r file; do
        if grep -q -E "(wget.*http|curl.*http|\.sh.*http)" "$file" 2>/dev/null; then
            deduct_score 15 "HIGH" "Подозрительная cron задача: $file"
            suspicious_cron=$((suspicious_cron + 1))
            echo "    🚨 Подозрительный cron: $file"
        fi
    done
    
    if [ "$suspicious_cron" -eq 0 ]; then
        print_success "Подозрительные cron задачи не обнаружены"
    fi
}

# Генерация отчета безопасности
generate_security_report() {
    local report_file="$REPORTS_DIR/security-audit-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ ОТЧЕТА БЕЗОПАСНОСТИ"
    
    print_header > "$report_file"
    echo "📅 Отчет создан: $(date)" >> "$report_file"
    echo "💻 Система: $(hostname) ($(uname -a))" >> "$report_file"
    echo "" >> "$report_file"
    
    # Сводка безопасности
    echo "🛡️  СВОДКА БЕЗОПАСНОСТИ" >> "$report_file"
    echo "======================" >> "$report_file"
    echo "Общий балл безопасности: $SECURITY_SCORE/100" >> "$report_file"
    echo "Критических проблем: $CRITICAL_ISSUES" >> "$report_file"
    echo "Высокоприоритетных проблем: $HIGH_ISSUES" >> "$report_file"
    echo "Средних проблем: $MEDIUM_ISSUES" >> "$report_file"
    echo "Низкоприоритетных проблем: $LOW_ISSUES" >> "$report_file"
    echo "" >> "$report_file"
    
    # Детальные результаты
    check_system_updates >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_password_policy >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_ssh_security >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_open_ports >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_suid_files >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_firewall >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_kernel_security >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_suspicious_processes >> "$report_file" 2>&1
    echo "" >> "$report_file"
    check_cron_jobs >> "$report_file" 2>&1
    
    # Рекомендации
    if [ "$SHOW_RECOMMENDATIONS" = "true" ]; then
        echo "💡 РЕКОМЕНДАЦИИ ПО БЕЗОПАСНОСТИ" >> "$report_file"
        echo "==============================" >> "$report_file"
        generate_recommendations >> "$report_file"
    fi
    
    print_success "Отчет сохранен: $report_file"
    echo "$SECURITY_SCORE" > "$SCORE_FILE"
}

# Генерация рекомендаций
generate_recommendations() {
    echo "  🔐 Общие рекомендации:"
    echo "    • Регулярно обновляйте систему и приложения"
    echo "    • Используйте сложные уникальные пароли"
    echo "    • Настройте двухфакторную аутентификацию где возможно"
    echo "    • Регулярно делайте резервные копии"
    echo "    • Мониторьте логи системы на подозрительную активность"
    echo ""
    
    if [ "$SECURITY_SCORE" -lt 70 ]; then
        echo "  🚨 КРИТИЧЕСКИЕ РЕКОМЕНДАЦИИ:" 
        echo "    • Немедленно устраните критические уязвимости"
        echo "    • Установите и настройте файрвол"
        echo "    • Отключите неиспользуемые сервисы"
        echo "    • Проверьте систему на наличие вредоносного ПО"
    fi
    
    if [ "$SECURITY_SCORE" -ge 85 ]; then
        echo "  ✅ Система в хорошем состоянии безопасности"
    fi
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "quick")
            print_header
            check_system_updates
            check_ssh_security
            check_firewall
            check_open_ports
            ;;
        "deep")
            print_header
            check_system_updates
            check_password_policy
            check_ssh_security
            check_open_ports
            check_suid_files
            check_firewall
            check_kernel_security
            check_suspicious_processes
            check_cron_jobs
            ;;
        "report")
            print_header
            generate_security_report
            ;;
        "config")
            create_config
            ;;
        "score")
            if [ -f "$SCORE_FILE" ]; then
                local last_score=$(cat "$SCORE_FILE")
                echo "Последний балл безопасности: $last_score/100"
            else
                echo "Балл безопасности не найден. Запустите аудит сначала."
            fi
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА]"
            echo ""
            echo "Команды:"
            echo "  quick    - Быстрая проверка основных параметров"
            echo "  deep     - Глубокий аудит безопасности"
            echo "  report   - Генерация детального отчета"
            echo "  config   - Создать конфигурационные файлы"
            echo "  score    - Показать последний балл безопасности"
            echo "  help     - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 quick"
            echo "  $0 deep"
            echo "  $0 report"
            echo "  $0 score"
            ;;
        *)
            print_header
            check_system_updates
            check_password_policy
            check_ssh_security
            check_open_ports
            check_suid_files
            check_firewall
            check_kernel_security
            generate_security_report
            ;;
    esac
}

# Инициализация
log_message "INFO" "Запуск аудита безопасности"
main "$@"
log_message "INFO" "Завершение аудита безопасности. Балл: $SECURITY_SCORE"
