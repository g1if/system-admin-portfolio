#!/bin/bash
# 👥 Менеджер пользователей и групп
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/user-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" 2>/dev/null || true

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_header() {
    echo -e "${MAGENTA}"
    echo "👥 ==========================================="
    echo "   МЕНЕДЖЕР ПОЛЬЗОВАТЕЛЕЙ И ГРУПП v1.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}👤 $1${NC}"
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

# Получение информации о пользователях
get_users_info() {
    print_section "ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЯХ"
    
    local total_users=0
    local system_users=0
    local regular_users=0
    
    # Общее количество пользователей
    if command -v getent >/dev/null 2>&1; then
        total_users=$(getent passwd | wc -l)
        system_users=$(getent passwd | grep -E ":/bin/false|/usr/sbin/nologin" | wc -l)
        regular_users=$((total_users - system_users))
        
        echo "  📊 Всего пользователей: $total_users"
        echo "  👤 Обычных пользователей: $regular_users"
        echo "  ⚙️  Системных пользователей: $system_users"
        
        # Последние залогиненные пользователи
        echo ""
        echo "  🔐 Последние вошедшие пользователи:"
        if command -v last >/dev/null 2>&1; then
            last -n 5 | head -n -2 | while read -r line; do
                if [ -n "$line" ]; then
                    echo "    👤 $line"
                fi
            done
        else
            echo "    ℹ️  Команда last не найдена"
        fi
    else
        echo "  ℹ️  Команда getent не найдена"
    fi
}

# Анализ групп
get_groups_info() {
    print_section "ИНФОРМАЦИЯ О ГРУППАХ"
    
    if command -v getent >/dev/null 2>&1; then
        local total_groups=$(getent group | wc -l)
        echo "  📊 Всего групп: $total_groups"
        
        echo ""
        echo "  👥 Группы с несколькими пользователями:"
        getent group | awk -F: '{if (NF == 4 && $4 != "") print $1 ": " $4}' | head -5 | while read -r group; do
            echo "    📋 $group"
        done
        
        # Проверка привилегированных групп
        echo ""
        echo "  🔐 Привилегированные группы:"
        local privileged_groups=("sudo" "wheel" "root" "adm" "staff")
        for group in "${privileged_groups[@]}"; do
            if getent group "$group" >/dev/null 2>&1; then
                local members=$(getent group "$group" | cut -d: -f4)
                echo "    ⚠️  $group: $members"
            fi
        done
    else
        echo "  ℹ️  Команда getent не найдена"
    fi
}

# Проверка парольной политики
check_password_policy() {
    print_section "ПОЛИТИКА ПАРОЛЕЙ"
    
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_warn_age=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}' | head -1)
        
        echo "  Макс. дней пароля: ${pass_max_days:-Не установлено}"
        echo "  Мин. дней пароля: ${pass_min_days:-Не установлено}"
        echo "  Предупреждение за дней: ${pass_warn_age:-Не установено}"
        
        if [ -n "$pass_max_days" ] && [ "$pass_max_days" -gt 90 ] 2>/dev/null; then
            print_status "WARN" "Слишком долгий срок жизни пароля (>90 дней)"
        fi
    else
        echo "  ℹ️  Файл login.defs не найден"
    fi
    
    # Проверка сложности паролей
    if [ -f /etc/pam.d/common-password ] || [ -f /etc/pam.d/system-auth ]; then
        echo "  🔒 Проверка политики сложности паролей..."
        if grep -q "pam_pwquality" /etc/pam.d/common-password 2>/dev/null || grep -q "pam_cracklib" /etc/pam.d/common-password 2>/dev/null; then
            print_status "OK" "Политика сложности паролей включена"
        else
            print_status "INFO" "Политика сложности паролей не настроена"
        fi
    fi
}

# Проверка учетных записей
check_accounts() {
    print_section "ПРОВЕРКА УЧЕТНЫХ ЗАПИСЕЙ"
    
    # Проверка учетных записей без пароля
    echo "  🔍 Поиск учетных записей без пароля..."
    local empty_password_count=0
    
    if [ -r /etc/shadow ]; then
        while IFS=: read -r user pass; do
            if [ -z "$pass" ] || [ "$pass" = "!" ] || [ "$pass" = "*" ]; then
                echo "    🔓 $user: пустой пароль или вход заблокирован"
                empty_password_count=$((empty_password_count + 1))
            fi
        done < /etc/shadow
        
        if [ "$empty_password_count" -eq 0 ]; then
            print_status "OK" "Учетных записей без пароля не найдено"
        else
            print_status "WARN" "Найдено учетных записей без пароля: $empty_password_count"
        fi
    else
        echo "    ℹ️  Нет доступа к /etc/shadow"
    fi
    
    # Проверка устаревших учетных записей
    echo ""
    echo "  📅 Поиск неактивных учетных записей..."
    local inactive_users=0
    
    if command -v lastlog >/dev/null 2>&1; then
        lastlog | grep -v "Never logged in" | grep -v "Username" | while read -r line; do
            local user=$(echo "$line" | awk '{print $1}')
            local last_login=$(echo "$line" | awk '{print $4, $5, $6, $7}')
            echo "    ⏰ $user: последний вход $last_login"
            inactive_users=$((inactive_users + 1))
        done
    else
        echo "    ℹ️  Команда lastlog не найдена"
    fi
}

# Создание тестового пользователя (только с sudo)
create_test_user() {
    print_section "СОЗДАНИЕ ТЕСТОВОГО ПОЛЬЗОВАТЕЛЯ"
    
    if [ "$EUID" -ne 0 ]; then
        echo "  ℹ️  Для создания пользователя требуются права root"
        return
    fi
    
    local test_user="testuser_$(date +%s)"
    
    echo "  Создаем тестового пользователя: $test_user"
    
    if useradd -m -s /bin/bash -c "Test User" "$test_user" 2>/dev/null; then
        echo "    🎉 Пользователь $test_user создан"
        echo "    🏠 Домашняя директория: /home/$test_user"
        
        # Устанавливаем простой пароль
        echo "$test_user:testpass123" | chpasswd 2>/dev/null && echo "    🔑 Пароль установлен"
        
        # Создаем тестовую группу
        local test_group="testgroup_$(date +%s)"
        if groupadd "$test_group" 2>/dev/null; then
            echo "    👥 Группа $test_group создана"
            usermod -a -G "$test_group" "$test_user" 2>/dev/null && echo "    ✅ Пользователь добавлен в группу"
        fi
        
        print_status "OK" "Тестовый пользователь создан успешно"
        echo "    💡 Для удаления выполните: sudo userdel -r $test_user"
    else
        print_status "ERROR" "Ошибка создания тестового пользователя"
    fi
}

# Основная функция
main() {
    print_header
    log "Запуск менеджера пользователей"
    
    get_users_info
    get_groups_info
    check_password_policy
    check_accounts
    
    echo ""
    echo -e "${GREEN}✅ Аудит пользователей завершен${NC}"
    log "Аудит пользователей завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Функции для обработки команд
cmd_create_test() {
    if [ "$EUID" -eq 0 ]; then
        create_test_user
    else
        echo -e "${YELLOW}⚠️  Для создания тестового пользователя требуются права root${NC}"
        echo "  Запустите: sudo $0 create-test"
    fi
}

cmd_list_users() {
    print_header
    get_users_info
}

cmd_list_groups() {
    print_header
    get_groups_info
}

cmd_help() {
    echo -e "${CYAN}👥 Менеджер пользователей и групп - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  create-test - создать тестового пользователя (требует sudo)"
    echo "  list-users  - список пользователей"
    echo "  list-groups - список групп"
    echo "  help        - эта справка"
    echo ""
    echo "Без аргументов: полный аудит пользователей и групп"
    echo ""
    echo "Примеры:"
    echo "  $0                    # Полный аудит"
    echo "  sudo $0 create-test   # Создать тестового пользователя"
    echo "  $0 list-users         # Только список пользователей"
}

# Обработка аргументов
case "${1:-}" in
    "create-test") cmd_create_test ;;
    "list-users") cmd_list_users ;;
    "list-groups") cmd_list_groups ;;
    "help") cmd_help ;;
    *) main ;;
esac
