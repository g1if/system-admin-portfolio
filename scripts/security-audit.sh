#!/bin/bash
# 🔒 Скрипт аудита безопасности системы
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -euo pipefail

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
    echo "   АУДИТ БЕЗОПАСНОСТИ СИСТЕМЫ v1.0"
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

# Проверка обновлений системы
check_updates() {
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ СИСТЕМЫ"
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        if check_command "apt"; then
            echo "  Проверка обновлений apt..."
            local update_count=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
            if [ $update_count -gt 0 ]; then
                print_status "WARN" "Доступно обновлений: $update_count"
                echo "    Запустите: sudo apt update && sudo apt upgrade"
            else
                print_status "OK" "Система обновлена"
            fi
        fi
    else
        echo "  ℹ️  Проверка обновлений: доступно только для Debian/Ubuntu"
    fi
}

# Проверка парольной политики
check_password_policy() {
    print_section "ПРОВЕРКА ПАРОЛЬНОЙ ПОЛИТИКИ"
    
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
        local pass_min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
        local pass_warn_age=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}')
        
        echo "  Макс. дней пароля: ${pass_max_days:-Не установлено}"
        echo "  Мин. дней пароля: ${pass_min_days:-Не установлено}"
        echo "  Предупреждение за дней: ${pass_warn_age:-Не установлено}"
        
        if [ "${pass_max_days:-0}" -gt 90 ]; then
            print_status "WARN" "Слишком долгий срок жизни пароля (>90 дней)"
        else
            print_status "OK" "Политика срока жизни пароля в норме"
        fi
    else
        print_status "WARN" "Файл login.defs не найден"
    fi
}

# Проверка SSH безопасности
check_ssh_security() {
    print_section "ПРОВЕРКА БЕЗОПАСНОСТИ SSH"
    
    if [ -f /etc/ssh/sshd_config ]; then
        local permit_root=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | tail -1 | awk '{print $2}')
        local password_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | tail -1 | awk '{print $2}')
        local protocol=$(grep -i "^Protocol" /etc/ssh/sshd_config | tail -1 | awk '{print $2}')
        
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
    else
        print_status "WARN" "Файл sshd_config не найден"
    fi
}

# Проверка открытых портов
check_open_ports() {
    print_section "ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ"
    
    if check_command "ss"; then
        echo "  Слушающие порты:"
        ss -tulpn | grep LISTEN | while read line; do
            local port=$(echo $line | awk '{print $5}' | rev | cut -d: -f1 | rev)
            local service=$(echo $line | awk '{print $7}')
            echo "    Порт $port: $service"
        done
    elif check_command "netstat"; then
        echo "  Слушающие порты:"
        netstat -tulpn 2>/dev/null | grep LISTEN | while read line; do
            local port=$(echo $line | awk '{print $4}' | rev | cut -d: -f1 | rev)
            local service=$(echo $line | awk '{print $7}')
            echo "    Порт $port: $service"
        done
    else
        echo "  ℹ️  Команды ss/netstat не найдены"
    fi
}

# Проверка SUID файлов
check_suid_files() {
    print_section "ПРОВЕРКА SUID ФАЙЛОВ"
    
    local suid_count=0
    if check_command "find"; then
        suid_count=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
        echo "  Найдено SUID файлов: $suid_count"
        
        if [ $suid_count -gt 50 ]; then
            print_status "WARN" "Много SUID файлов ($suid_count), рекомендуется проверить"
        else
            print_status "OK" "Количество SUID файлов в норме"
        fi
    else
        echo "  ℹ️  Команда find не найдена"
    fi
}

# Проверка пользователей
check_users() {
    print_section "ПРОВЕРКА ПОЛЬЗОВАТЕЛЕЙ"
    
    local users_with_shell=$(getent passwd | grep -v "nologin" | grep -v "false" | cut -d: -f1 | wc -l)
    local empty_password=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
    
    echo "  Пользователей с shell: $users_with_shell"
    echo "  Пользователей с пустым паролем: $empty_password"
    
    if [ $empty_password -gt 0 ]; then
        print_status "ERROR" "Обнаружены пользователи с пустыми паролями!"
    else
        print_status "OK" "Пустые пароли не обнаружены"
    fi
}

# Проверка файрвола
check_firewall() {
    print_section "ПРОВЕРКА ФАЙРВОЛА"
    
    if check_command "ufw"; then
        local ufw_status=$(ufw status 2>/dev/null | grep "Status")
        echo "  UFW: $ufw_status"
        
        if echo "$ufw_status" | grep -q "active"; then
            print_status "OK" "UFW включен"
        else
            print_status "WARN" "UFW отключен"
        fi
    elif check_command "iptables"; then
        local iptables_rules=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo 0)
        echo "  Правил iptables: $iptables_rules"
        
        if [ $iptables_rules -gt 0 ]; then
            print_status "OK" "IPTables настроен"
        else
            print_status "WARN" "IPTables не настроен"
        fi
    else
        print_status "WARN" "Файрвол не обнаружен"
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
        check_updates
        check_ssh_security
        check_firewall
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
EOF
