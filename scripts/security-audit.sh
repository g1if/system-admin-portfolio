#!/bin/bash
# 🔒 Скрипт аудита безопасности системы
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/security-audit.log"

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
    echo "🔒 ==========================================="
    echo "   АУДИТ БЕЗОПАСНОСТИ СИСТЕМЫ v1.1"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}🔍 $1${NC}"
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

# Безопасное получение числового значения
safe_number() {
    local value="$1"
    # Убираем все нецифровые символы
    value=$(echo "$value" | tr -cd '0-9')
    if [ -z "$value" ]; then
        echo "0"
    else
        echo "$value"
    fi
}

# Проверка обновлений системы

check_updates() {
    echo -e "${BLUE}🔍 ПРОВЕРКА ОБНОВЛЕНИЙ СИСТЕМЫ${NC}"
    
    if command -v apt-get &> /dev/null; then
        echo "  Проверка обновлений apt..."
        updates=$(apt list --upgradable 2>/dev/null | wc -l)
        if [ "$updates" -gt 1 ]; then
            echo -e "  ${YELLOW}⚠️  Доступно обновлений: $((updates-1))${NC}"
        else
            echo -e "  ${GREEN}✅ Система обновлена${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  Менеджер пакетов apt не найден${NC}"
    fi
}

# Проверка парольной политики
check_password_policy() {
    print_section "ПРОВЕРКА ПАРОЛЬНОЙ ПОЛИТИКИ"
    
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_warn_age=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}' | head -1)
        
        pass_max_days=$(safe_number "$pass_max_days")
        pass_min_days=$(safe_number "$pass_min_days")
        pass_warn_age=$(safe_number "$pass_warn_age")
        
        echo "  Макс. дней пароля: ${pass_max_days:-Не установлено}"
        echo "  Мин. дней пароля: ${pass_min_days:-Не установлено}"
        echo "  Предупреждение за дней: ${pass_warn_age:-Не установлено}"
        
        if [ "$pass_max_days" -gt 90 ] 2>/dev/null; then
            print_status "WARN" "Слишком долгий срок жизни пароля (>90 дней)"
        elif [ "$pass_max_days" -gt 0 ] 2>/dev/null; then
            print_status "OK" "Политика срока жизни пароля в норме"
        else
            print_status "WARN" "Политика срока жизни пароля не настроена"
        fi
    else
        print_status "WARN" "Файл login.defs не найден"
    fi
}

# Проверка SSH безопасности
check_ssh_security() {
    print_section "ПРОВЕРКА БЕЗОПАСНОСТИ SSH"
    
    local sshd_config_locations=(
        "/etc/ssh/sshd_config"
        "/etc/sshd_config"
        "/usr/local/etc/ssh/sshd_config"
    )
    
    local sshd_config_found=""
    
    for config in "${sshd_config_locations[@]}"; do
        if [ -f "$config" ]; then
            sshd_config_found="$config"
            break
        fi
    done
    
    if [ -n "$sshd_config_found" ]; then
        local permit_root=$(grep -i "^PermitRootLogin" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ')
        local password_auth=$(grep -i "^PasswordAuthentication" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ')
        local protocol=$(grep -i "^Protocol" "$sshd_config_found" | tail -1 | awk '{print $2}' | tr -d ' ')
        
        echo "  Файл конфигурации: $sshd_config_found"
        echo "  Root доступ: ${permit_root:-Не установлено}"
        echo "  Аутентификация паролем: ${password_auth:-Не установлено}"
        echo "  Протокол: ${protocol:-Не установлено}"
        
        if [ "${permit_root:-yes}" = "yes" ]; then
            print_status "WARN" "Root доступ по SSH разрешен"
        else
            print_status "OK" "Root доступ по SSH запрещен"
        fi
        
        if [ "${password_auth:-yes}" = "yes" ]; then
            print_status "WARN" "Аутентификация паролем разрешена"
        else
            print_status "OK" "Аутентификация только по ключу"
        fi
        
        if [ "${protocol:-2}" = "2" ]; then
            print_status "OK" "Используется протокол SSH 2"
        else
            print_status "WARN" "Устаревшая версия протокола SSH"
        fi
    else
        print_status "INFO" "SSH сервер не установлен или конфиг не найден"
    fi
}

# Проверка открытых портов
check_open_ports() {
    print_section "ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ"
    
    local port_count=0
    
    if check_command "ss"; then
        echo "  Слушающие порты:"
        ss -tulpn 2>/dev/null | grep LISTEN | while read -r line; do
            local port=$(echo "$line" | awk '{print $5}' | rev | cut -d: -f1 | rev)
            local service=$(echo "$line" | awk '{print $7}' | cut -d'"' -f2)
            if [ -n "$port" ] && [ "$port" != "Address" ]; then
                echo "    Порт $port: ${service:-unknown}"
                port_count=$((port_count + 1))
            fi
        done
    elif check_command "netstat"; then
        echo "  Слушающие порты:"
        netstat -tulpn 2>/dev/null | grep LISTEN | while read -r line; do
            local port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
            local service=$(echo "$line" | awk '{print $7}')
            if [ -n "$port" ] && [ "$port" != "Address" ]; then
                echo "    Порт $port: ${service:-unknown}"
                port_count=$((port_count + 1))
            fi
        done
    else
        echo "  ℹ️  Команды ss/netstat не найдены"
        return
    fi
    
    if [ "$port_count" -eq 0 ]; then
        echo "  ℹ️  Открытые порты не найдены"
    fi
}

# Проверка SUID файлов
check_suid_files() {
    print_section "ПРОВЕРКА SUID ФАЙЛОВ"
    
    if check_command "find"; then
        echo "  Поиск SUID файлов (может занять время)..."
        local suid_count=0
        # Ищем SUID файлы, исключая некоторые стандартные пути
        suid_count=$(find / -type f -perm -4000 2>/dev/null | \
                    grep -v "^/proc" | \
                    grep -v "^/sys" | \
                    grep -v "^/dev" | \
                    grep -v "^/run" | \
                    wc -l)
        
        suid_count=$(safe_number "$suid_count")
        echo "  Найдено SUID файлов: $suid_count"
        
        if [ "$suid_count" -gt 100 ]; then
            print_status "WARN" "Много SUID файлов ($suid_count), рекомендуется проверить"
        elif [ "$suid_count" -gt 0 ]; then
            print_status "OK" "Количество SUID файлов в норме"
        else
            print_status "INFO" "SUID файлы не найдены"
        fi
    else
        echo "  ℹ️  Команда find не найдена"
    fi
}

# Проверка пользователей
check_users() {
    print_section "ПРОВЕРКА ПОЛЬЗОВАТЕЛЕЙ"
    
    local users_with_shell=0
    local empty_password=0
    
    if check_command "getent"; then
        users_with_shell=$(getent passwd | grep -v "nologin" | grep -v "false" | cut -d: -f1 | wc -l)
        users_with_shell=$(safe_number "$users_with_shell")
        
        if [ -f /etc/shadow ] && [ -r /etc/shadow ]; then
            empty_password=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null | wc -l)
            empty_password=$(safe_number "$empty_password")
        else
            empty_password="N/A"
        fi
        
        echo "  Пользователей с shell: $users_with_shell"
        echo "  Пользователей с пустым паролем: $empty_password"
        
        if [ "$empty_password" != "N/A" ] && [ "$empty_password" -gt 0 ]; then
            print_status "ERROR" "Обнаружены пользователи с пустыми паролями!"
        else
            print_status "OK" "Пустые пароли не обнаружены"
        fi
    else
        echo "  ℹ️  Команда getent не найдена"
    fi
}

# Проверка файрвола
check_firewall() {
    print_section "ПРОВЕРКА ФАЙРВОЛА"
    
    local firewall_found=0
    
    if check_command "ufw"; then
        firewall_found=1
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1 || echo "Status: unknown")
        echo "  UFW: $ufw_status"
        
        if echo "$ufw_status" | grep -q "active"; then
            print_status "OK" "UFW включен"
            
            # Показываем правила
            local ufw_rules=$(ufw status numbered 2>/dev/null | grep -c "^\[" || echo 0)
            echo "  Правил UFW: $ufw_rules"
        else
            print_status "WARN" "UFW отключен"
        fi
    fi
    
    if check_command "iptables"; then
        firewall_found=1
        local iptables_rules=0
        if iptables -L INPUT 2>/dev/null | grep -q "policy DROP"; then
            iptables_rules=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo 0)
            echo "  IPTables: настроен (политика DROP на INPUT)"
            echo "  Правил iptables: $iptables_rules"
            print_status "OK" "IPTables настроен"
        else
            echo "  IPTables: базовая политика не DROP"
            print_status "WARN" "IPTables не настроен строго"
        fi
    fi
    
    if check_command "firewalld"; then
        firewall_found=1
        if systemctl is-active firewalld >/dev/null 2>&1; then
            echo "  Firewalld: активен"
            print_status "OK" "Firewalld включен"
        else
            echo "  Firewalld: не активен"
            print_status "WARN" "Firewalld отключен"
        fi
    fi
    
    if [ "$firewall_found" -eq 0 ]; then
        print_status "WARN" "Файрвол не обнаружен"
    fi
}

# Проверка настроек ядра
check_kernel_security() {
    print_section "ПРОВЕРКА НАСТРОЕК ЯДРА"
    
    local kernel_settings=(
        "net.ipv4.ip_forward:0"
        "kernel.dmesg_restrict:1"
        "kernel.kptr_restrict:2"
        "net.ipv4.conf.all.accept_redirects:0"
        "net.ipv4.conf.all.send_redirects:0"
    )
    
    local secure_count=0
    local total_checks=${#kernel_settings[@]}
    
    for setting in "${kernel_settings[@]}"; do
        local key="${setting%:*}"
        local expected="${setting#*:}"
        local actual
        
        if actual=$(sysctl -n "$key" 2>/dev/null); then
            if [ "$actual" = "$expected" ]; then
                secure_count=$((secure_count + 1))
                echo "  ✅ $key = $actual"
            else
                echo "  ⚠️  $key = $actual (ожидается: $expected)"
            fi
        else
            echo "  ❓ $key: недоступно"
        fi
    done
    
    if [ "$secure_count" -eq "$total_checks" ]; then
        print_status "OK" "Настройки ядра безопасны"
    elif [ "$secure_count" -gt $((total_checks / 2)) ]; then
        print_status "WARN" "Некоторые настройки ядра не оптимальны"
    else
        print_status "ERROR" "Многие настройки ядра небезопасны"
    fi
}

# Основная функция
main() {
    print_header
    log "Запуск аудита безопасности"
    
    check_updates
    check_password_policy
    check_ssh_security
    check_open_ports
    check_suid_files
    check_users
    check_firewall
    check_kernel_security
    
    echo ""
    echo -e "${GREEN}✅ Аудит безопасности завершен${NC}"
    log "Аудит безопасности завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}💡 Рекомендации по безопасности:${NC}"
    echo "  - Регулярно обновляйте систему"
    echo "  - Используйте сложные пароли"
    echo "  - Отключите root доступ по SSH"
    echo "  - Настройте файрвол"
    echo "  - Проводите аудит периодически"
}

# Обработка аргументов
case "${1:-}" in
    "quick")
        # Быстрая проверка
        echo -e "${CYAN}🔍 Быстрая проверка безопасности...${NC}"
        check_updates
        check_ssh_security
        check_firewall
        check_open_ports
        ;;
    "help")
        echo "Использование: $0 [quick|help]"
        echo "  quick - быстрая проверка основных параметров"
        echo "  help  - эта справка"
        echo ""
        echo "Без аргументов: полная проверка безопасности"
        ;;
    *)
        main
        ;;
esac
