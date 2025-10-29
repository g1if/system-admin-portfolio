#!/bin/bash
# 👥 Продвинутый менеджер пользователей, групп и политик безопасности
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
LOG_FILE="$LOG_DIR/user-manager.log"
MAIN_CONFIG="$CONFIG_DIR/user-manager.conf"

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
    
    for cmd in getent awk grep cut sort uniq date passwd chage usermod groupadd; do
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
    echo "👥 ==========================================="
    echo "   ПРОДВИНУТЫЙ МЕНЕДЖЕР ПОЛЬЗОВАТЕЛЕЙ v2.0"
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
        "CRITICAL") echo -e "  ${RED}🚨 $message${NC}" ;;
    esac
}

# Создание конфигурации
create_config() {
    cat > "$MAIN_CONFIG" << 'EOF'
# Конфигурация менеджера пользователей v2.0

# Настройки аудита
AUDIT_SYSTEM_USERS=true
AUDIT_PRIVILEGED_GROUPS=true
CHECK_PASSWORD_POLICY=true
CHECK_ACCOUNT_SECURITY=true
CHECK_SESSION_SECURITY=true

# Привилегированные группы для мониторинга
PRIVILEGED_GROUPS=("sudo" "wheel" "root" "adm" "staff" "docker" "lxd")

# Пороговые значения
PASSWORD_MAX_DAYS_WARN=90
PASSWORD_MIN_DAYS_WARN=0
INACTIVE_DAYS_WARN=90
LAST_LOGIN_DAYS_WARN=180

# Настройки безопасности
CHECK_EMPTY_PASSWORDS=true
CHECK_UID_0_USERS=true
CHECK_HOME_PERMISSIONS=true
CHECK_SUDO_ACCESS=true

# Настройки отчетов
REPORT_ENABLED=true
REPORT_RETENTION_DAYS=30
AUTO_GENERATE_REPORT=true

# Дополнительные настройки
ENABLE_SESSION_MONITORING=false
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
        PRIVILEGED_GROUPS=("sudo" "wheel" "root" "adm" "staff")
        PASSWORD_MAX_DAYS_WARN=90
        INACTIVE_DAYS_WARN=90
        LAST_LOGIN_DAYS_WARN=180
        CHECK_EMPTY_PASSWORDS=true
        CHECK_UID_0_USERS=true
        CHECK_SUDO_ACCESS=true
    fi
}

# Отправка оповещений
send_alert() {
    local level=$1
    local message=$2
    local user=${3:-""}
    
    local full_message="[$level] $message"
    if [ -n "$user" ]; then
        full_message="[$level] Пользователь $user: $message"
    fi
    
    # Логирование всегда
    log "$level" "$message"
    
    # Console оповещения
    case $level in
        "CRITICAL") print_status "CRITICAL" "$message" ;;
        "ERROR") print_status "ERROR" "$message" ;;
        "WARN") print_status "WARN" "$message" ;;
        "INFO") print_status "INFO" "$message" ;;
    esac
}

# Получение детальной информации о пользователях
get_users_info() {
    print_section "ДЕТАЛЬНАЯ ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЯХ"
    
    local total_users=0
    local system_users=0
    local regular_users=0
    local locked_users=0
    
    if ! command -v getent >/dev/null 2>&1; then
        print_status "ERROR" "Команда getent не найдена"
        return 1
    fi
    
    # Общее количество пользователей
    total_users=$(getent passwd | wc -l)
    system_users=$(getent passwd | grep -E ":/bin/false|/usr/sbin/nologin|:/sbin/nologin" | wc -l)
    regular_users=$((total_users - system_users))
    
    # Подсчет заблокированных пользователей
    if [ -r /etc/shadow ]; then
        locked_users=$(awk -F: '($2 ~ /^\!/ || $2 ~ /^\*/) && $2 != "" {print $1}' /etc/shadow | wc -l)
    fi
    
    echo "  📊 Общая статистика:"
    echo "    Всего пользователей: $total_users"
    echo "    👤 Обычных пользователей: $regular_users"
    echo "    ⚙️  Системных пользователей: $system_users"
    echo "    🔒 Заблокированных: $locked_users"
    
    # Последние залогиненные пользователи
    echo ""
    echo "  🔐 Активные сессии и последние входы:"
    if command -v who >/dev/null 2>&1; then
        local active_users=$(who | wc -l)
        echo "    Активные сессии: $active_users"
        who | head -3 | while read -r line; do
            echo "    💻 $line"
        done
    fi
    
    echo ""
    if command -v last >/dev/null 2>&1; then
        echo "    Последние входы:"
        last -n 5 | head -n -2 | while read -r line; do
            if [ -n "$line" ]; then
                echo "    👤 $line"
            fi
        done
    else
        echo "    ℹ️  Команда last не найдена"
    fi
    
    # Пользователи с UID 0 (кроме root)
    if [ "$CHECK_UID_0_USERS" = "true" ]; then
        echo ""
        echo "  🔍 Проверка пользователей с UID 0:"
        local uid0_users=$(getent passwd | awk -F: '($3 == "0") {print $1}' | grep -v "^root$")
        if [ -n "$uid0_users" ]; then
            send_alert "CRITICAL" "Обнаружены пользователи с UID 0: $uid0_users"
        else
            print_status "OK" "Только root имеет UID 0"
        fi
    fi
}

# Расширенный анализ групп
get_groups_info() {
    print_section "РАСШИРЕННАЯ ИНФОРМАЦИЯ О ГРУППАХ"
    
    if ! command -v getent >/dev/null 2>&1; then
        print_status "ERROR" "Команда getent не найдена"
        return 1
    fi
    
    local total_groups=$(getent group | wc -l)
    echo "  📊 Всего групп: $total_groups"
    
    # Группы с несколькими пользователями
    echo ""
    echo "  👥 Группы с несколькими пользователями:"
    getent group | awk -F: '{if (NF == 4 && $4 != "") print $1 ": " $4}' | head -8 | while read -r group; do
        echo "    📋 $group"
    done
    
    # Проверка привилегированных групп
    if [ "$AUDIT_PRIVILEGED_GROUPS" = "true" ]; then
        echo ""
        echo "  🔐 Аудит привилегированных групп:"
        for group in "${PRIVILEGED_GROUPS[@]}"; do
            if getent group "$group" >/dev/null 2>&1; then
                local members=$(getent group "$group" | cut -d: -f4)
                if [ -n "$members" ]; then
                    echo -n "    ⚠️  $group: $members"
                    local member_count=$(echo "$members" | tr ',' '\n' | wc -l)
                    echo " ($member_count пользователей)"
                    
                    # Проверка на наличие нестандартных пользователей
                    if [ "$group" = "sudo" ] || [ "$group" = "wheel" ]; then
                        echo "$members" | tr ',' '\n' | while read -r user; do
                            if [ "$user" != "root" ] && [ "$user" != "$SUDO_USER" ]; then
                                local user_uid=$(id -u "$user" 2>/dev/null)
                                if [ "$user_uid" -lt 1000 ] 2>/dev/null; then
                                    send_alert "WARN" "Системный пользователь $user в привилегированной группе $group"
                                fi
                            fi
                        done
                    fi
                else
                    echo "    ✅ $group: нет пользователей"
                fi
            fi
        done
    fi
}

# Расширенная проверка парольной политики
check_password_policy() {
    print_section "РАСШИРЕННАЯ ПРОВЕРКА ПОЛИТИКИ ПАРОЛЕЙ"
    
    local has_issues=0
    
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}' | head -1)
        local pass_warn_age=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}' | head -1)
        
        echo "  ⚙️  Настройки в /etc/login.defs:"
        echo "    Макс. дней пароля: ${pass_max_days:-Не установлено}"
        echo "    Мин. дней пароля: ${pass_min_days:-Не установлено}"
        echo "    Предупреждение за дней: ${pass_warn_age:-Не установлено}"
        
        if [ -n "$pass_max_days" ] && [ "$pass_max_days" -gt "$PASSWORD_MAX_DAYS_WARN" ] 2>/dev/null; then
            send_alert "WARN" "Слишком долгий срок жизни пароля (>$PASSWORD_MAX_DAYS_WARN дней)"
            has_issues=1
        fi
        
        if [ -n "$pass_min_days" ] && [ "$pass_min_days" -eq 0 ] 2>/dev/null; then
            send_alert "WARN" "Мин. дней пароля равен 0 - пользователи могут менять пароль сразу"
            has_issues=1
        fi
    else
        echo "  ℹ️  Файл login.defs не найден"
    fi
    
    # Проверка сложности паролей в PAM
    echo ""
    echo "  🔒 Политика сложности паролей:"
    local pam_files=("/etc/pam.d/common-password" "/etc/pam.d/system-auth" "/etc/pam.d/password-auth")
    local found_policy=0
    
    for pam_file in "${pam_files[@]}"; do
        if [ -f "$pam_file" ]; then
            if grep -q "pam_pwquality" "$pam_file" 2>/dev/null || grep -q "pam_cracklib" "$pam_file" 2>/dev/null; then
                print_status "OK" "Политика сложности паролей включена ($pam_file)"
                found_policy=1
                break
            fi
        fi
    done
    
    if [ "$found_policy" -eq 0 ]; then
        send_alert "WARN" "Политика сложности паролей не настроена"
        has_issues=1
    fi
    
    # Проверка старых паролей пользователей
    if command -v chage >/dev/null 2>&1 && [ -r /etc/shadow ]; then
        echo ""
        echo "  📅 Сроки действия паролей пользователей:"
        getent passwd | while IFS=: read -r username _ uid _ _ home shell; do
            # Пропускаем системных пользователей
            if [ "$uid" -ge 1000 ] || [ "$uid" -eq 0 ]; then
                local last_change=$(chage -l "$username" 2>/dev/null | grep "Last password change" | cut -d: -f2)
                local expires=$(chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2)
                
                if echo "$expires" | grep -q "never"; then
                    echo "    ⚠️  $username: пароль никогда не истекает"
                elif echo "$expires" | grep -q "password must be changed"; then
                    echo "    🚨 $username: требуется смена пароля"
                fi
            fi
        done | head -5
    fi
    
    return $has_issues
}

# Расширенная проверка учетных записей
check_accounts() {
    print_section "РАСШИРЕННАЯ ПРОВЕРКА УЧЕТНЫХ ЗАПИСЕЙ"
    
    local has_issues=0
    
    # Проверка учетных записей без пароля
    if [ "$CHECK_EMPTY_PASSWORDS" = "true" ]; then
        echo "  🔍 Поиск учетных записей без пароля..."
        local empty_password_count=0
        
        if [ -r /etc/shadow ]; then
            while IFS=: read -r user pass; do
                if [ -z "$pass" ] || [ "$pass" = "!" ] || [ "$pass" = "*" ]; then
                    local uid=$(id -u "$user" 2>/dev/null)
                    # Проверяем только несистемных пользователей
                    if [ "$uid" -ge 1000 ] || [ "$user" = "root" ]; then
                        echo "    🔓 $user: пустой пароль или вход заблокирован"
                        empty_password_count=$((empty_password_count + 1))
                    fi
                fi
            done < /etc/shadow
            
            if [ "$empty_password_count" -eq 0 ]; then
                print_status "OK" "Учетных записей без пароля не найдено"
            else
                send_alert "CRITICAL" "Найдено учетных записей без пароля: $empty_password_count"
                has_issues=1
            fi
        else
            echo "    ℹ️  Нет доступа к /etc/shadow"
        fi
    fi
    
    # Проверка устаревших учетных записей
    echo ""
    echo "  📅 Поиск неактивных учетных записей..."
    
    if command -v lastlog >/dev/null 2>&1; then
        local current_timestamp=$(date +%s)
        local warning_timestamp=$((current_timestamp - LAST_LOGIN_DAYS_WARN * 86400))
        
        lastlog | tail -n +2 | while read -r line; do
            local user=$(echo "$line" | awk '{print $1}')
            local last_login=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf $i" "; print ""}' | sed 's/ *$//')
            
            if [ "$last_login" != "**Never logged in**" ]; then
                local login_date=$(date -d "$last_login" +%s 2>/dev/null || echo "0")
                if [ "$login_date" -lt "$warning_timestamp" ] && [ "$login_date" -ne 0 ]; then
                    local days_ago=$(( (current_timestamp - login_date) / 86400 ))
                    echo "    ⏰ $user: последний вход $days_ago дней назад ($last_login)"
                fi
            fi
        done | head -5
    else
        echo "    ℹ️  Команда lastlog не найдена"
    fi
    
    # Проверка домашних директорий
    if [ "$CHECK_HOME_PERMISSIONS" = "true" ]; then
        echo ""
        echo "  🏠 Проверка прав домашних директорий..."
        getent passwd | while IFS=: read -r username _ uid _ _ home shell; do
            if [ "$uid" -ge 1000 ] && [ -d "$home" ]; then
                local perms=$(stat -c "%A %U %G" "$home" 2>/dev/null)
                local owner=$(echo "$perms" | awk '{print $2}')
                local group=$(echo "$perms" | awk '{print $3}')
                
                if [ "$owner" != "$username" ]; then
                    echo "    ⚠️  $username: домашняя директория принадлежит $owner"
                fi
                
                # Проверяем наличие прав записи у группы/других
                if stat -c "%A" "$home" 2>/dev/null | grep -q "^d......w"; then
                    echo "    ⚠️  $username: группа имеет право записи в домашнюю директорию"
                fi
            fi
        done | head -3
    fi
    
    return $has_issues
}

# Проверка sudo доступа
check_sudo_access() {
    if [ "$CHECK_SUDO_ACCESS" != "true" ]; then
        return
    fi
    
    print_section "ПРОВЕРКА SUDO ДОСТУПА"
    
    if ! command -v sudo >/dev/null 2>&1; then
        echo "  ℹ️  Sudo не установлен"
        return
    fi
    
    # Пользователи с sudo доступом
    echo "  👥 Пользователи с sudo доступом:"
    
    # Через группу sudo/wheel
    for group in sudo wheel; do
        if getent group "$group" >/dev/null 2>&1; then
            local members=$(getent group "$group" | cut -d: -f4)
            if [ -n "$members" ]; then
                echo "    Группа $group: $members"
            fi
        fi
    done
    
    # Через sudoers файлы
    echo ""
    echo "  📋 Настройки в sudoers:"
    if [ -f /etc/sudoers ]; then
        grep -v "^#" /etc/sudoers | grep -v "^$" | grep -v "^Defaults" | while read -r line; do
            if [ -n "$line" ]; then
                echo "    ⚙️  $line"
            fi
        done | head -5
    fi
    
    # Проверка файлов в sudoers.d
    if [ -d /etc/sudoers.d ]; then
        for file in /etc/sudoers.d/*; do
            if [ -f "$file" ] && [ -r "$file" ]; then
                local user_rules=$(grep -v "^#" "$file" | grep -v "^$" | grep -v "^Defaults" | head -2)
                if [ -n "$user_rules" ]; then
                    echo "    📁 $file:"
                    echo "$user_rules" | while read -r rule; do
                        echo "      ➡️  $rule"
                    done
                fi
            fi
        done
    fi
}

# Создание тестового пользователя (только с sudo)
create_test_user() {
    print_section "СОЗДАНИЕ ТЕСТОВОГО ПОЛЬЗОВАТЕЛЯ"
    
    if [ "$EUID" -ne 0 ]; then
        print_status "ERROR" "Для создания пользователя требуются права root"
        echo "  💡 Запустите: sudo $0 create-test"
        return 1
    fi
    
    local test_user="testuser_$(date +%s)"
    local test_password="TestPass123!_$(date +%s)"
    
    echo "  Создаем тестового пользователя: $test_user"
    
    if useradd -m -s /bin/bash -c "Test User for Security Audit" "$test_user" 2>/dev/null; then
        print_status "OK" "Пользователь $test_user создан"
        echo "    🏠 Домашняя директория: /home/$test_user"
        
        # Устанавливаем надежный пароль
        if echo "$test_user:$test_password" | chpasswd 2>/dev/null; then
            echo "    🔑 Пароль установлен: $test_password"
        else
            print_status "WARN" "Не удалось установить пароль"
        fi
        
        # Создаем тестовую группу
        local test_group="testgroup_$(date +%s)"
        if groupadd "$test_group" 2>/dev/null; then
            echo "    👥 Группа $test_group создана"
            usermod -a -G "$test_group" "$test_user" 2>/dev/null && echo "    ✅ Пользователь добавлен в группу"
        fi
        
        # Настраиваем политику пароля
        if command -v chage >/dev/null 2>/dev/null; then
            chage -M 90 -m 7 -W 14 "$test_user" 2>/dev/null && echo "    ⚙️  Политика пароля настроена"
        fi
        
        print_status "OK" "Тестовый пользователь создан успешно"
        echo ""
        echo "  📋 Информация для удаления:"
        echo "    sudo userdel -r $test_user"
        echo "    sudo groupdel $test_group 2>/dev/null || true"
        
        log "INFO" "Создан тестовый пользователь: $test_user"
    else
        print_status "ERROR" "Ошибка создания тестового пользователя"
        log "ERROR" "Ошибка создания тестового пользователя"
    fi
}

# Генерация отчета
generate_report() {
    local manager=$1
    local report_file="$REPORTS_DIR/user-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ ОТЧЕТА ПОЛЬЗОВАТЕЛЕЙ"
    
    {
        echo "ОТЧЕТ ПОЛЬЗОВАТЕЛЕЙ И ГРУПП"
        echo "Сгенерирован: $(date)"
        echo "Система: $(uname -a)"
        echo "==========================================="
        echo ""
        
        echo "СТАТИСТИКА ПОЛЬЗОВАТЕЛЕЙ:"
        echo "------------------------"
        if command -v getent >/dev/null 2>&1; then
            local total_users=$(getent passwd | wc -l)
            local system_users=$(getent passwd | grep -E ":/bin/false|/usr/sbin/nologin" | wc -l)
            local regular_users=$((total_users - system_users))
            
            echo "Всего пользователей: $total_users"
            echo "Обычных пользователей: $regular_users"
            echo "Системных пользователей: $system_users"
        fi
        echo ""
        
        echo "ПРИВИЛЕГИРОВАННЫЕ ГРУППЫ:"
        echo "------------------------"
        for group in "${PRIVILEGED_GROUPS[@]}"; do
            if getent group "$group" >/dev/null 2>&1; then
                local members=$(getent group "$group" | cut -d: -f4)
                echo "$group: ${members:-нет пользователей}"
            fi
        done
        echo ""
        
        echo "ПРОБЛЕМЫ БЕЗОПАСНОСТИ:"
        echo "---------------------"
        if [ -r /etc/shadow ]; then
            local empty_passwords=$(awk -F: '($2 == "" || $2 == "!" || $2 == "*") && $2 != "!!" {print $1}' /etc/shadow | wc -l)
            echo "Учетных записей без пароля: $empty_passwords"
        fi
        
        local uid0_users=$(getent passwd | awk -F: '($3 == "0") {print $1}' | grep -v "^root$" | tr '\n' ' ')
        echo "Пользователей с UID 0 (кроме root): ${uid0_users:-нет}"
        
    } > "$report_file"
    
    print_status "OK" "Отчет сохранен: $report_file"
    log "INFO" "Сгенерирован отчет: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    load_config
    
    if [ "$CHECK_DEPENDENCIES" = "true" ] && ! check_dependencies; then
        exit 1
    fi
    
    print_header
    log "INFO" "Запуск расширенного аудита пользователей"
    
    get_users_info
    get_groups_info
    
    if [ "$CHECK_PASSWORD_POLICY" = "true" ]; then
        check_password_policy
    fi
    
    if [ "$CHECK_ACCOUNT_SECURITY" = "true" ]; then
        check_accounts
    fi
    
    check_sudo_access
    
    # Автогенерация отчета
    if [ "$AUTO_GENERATE_REPORT" = "true" ]; then
        echo ""
        generate_report > /dev/null
    fi
    
    echo ""
    print_status "OK" "Расширенный аудит пользователей завершен"
    log "INFO" "Аудит пользователей завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Команды
cmd_create_test() {
    create_test_user
}

cmd_list_users() {
    print_header
    get_users_info
}

cmd_list_groups() {
    print_header
    get_groups_info
}

cmd_check_security() {
    print_header
    load_config
    check_password_policy
    check_accounts
    check_sudo_access
}

cmd_report() {
    print_header
    generate_report
}

cmd_config() {
    create_config
}

cmd_monitor() {
    print_header
    echo "  🔍 РЕЖИМ МОНИТОРИНГА ПОЛЬЗОВАТЕЛЕЙ"
    echo "  ⏰ Обновление каждые 30 секунд"
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    export MONITOR_MODE="true"
    local counter=0
    
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "  📊 Цикл мониторинга #$counter ($(date '+%H:%M:%S'))"
        echo ""
        
        # Быстрая проверка активных пользователей
        echo "  👥 Активные пользователи:"
        who | head -10 | while read -r line; do
            echo "    💻 $line"
        done
        
        # Проверка привилегированных групп
        echo ""
        echo "  🔐 Привилегированные группы:"
        for group in sudo wheel; do
            if getent group "$group" >/dev/null 2>&1; then
                local members=$(getent group "$group" | cut -d: -f4)
                echo "    ⚠️  $group: $members"
            fi
        done
        
        echo ""
        echo "  ⏳ Следующее обновление через 30 сек..."
        sleep 30
    done
    
    export MONITOR_MODE="false"
}

cmd_help() {
    print_header
    echo -e "${CYAN}👥 Продвинутый менеджер пользователей - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  create-test   - создать тестового пользователя (требует sudo)"
    echo "  list-users    - детальная информация о пользователях"
    echo "  list-groups   - детальная информация о группах"
    echo "  check-security- проверка безопасности учетных записей"
    echo "  report        - генерация отчета"
    echo "  config        - создать конфигурационный файл"
    echo "  monitor       - мониторинг в реальном времени"
    echo "  help          - эта справка"
    echo ""
    echo "Без аргументов: полный расширенный аудит"
    echo ""
    echo "Примеры:"
    echo "  $0                    # Полный аудит"
    echo "  sudo $0 create-test   # Создать тестового пользователя"
    echo "  $0 list-users         # Информация о пользователях"
    echo "  $0 check-security     # Проверка безопасности"
    echo "  $0 monitor            # Мониторинг в реальном времени"
}

# Обработка аргументов
case "${1:-}" in
    "create-test") cmd_create_test ;;
    "list-users") cmd_list_users ;;
    "list-groups") cmd_list_groups ;;
    "check-security") cmd_check_security ;;
    "report") cmd_report ;;
    "config") cmd_config ;;
    "monitor") cmd_monitor ;;
    "help"|"--help"|"-h") cmd_help ;;
    *) main ;;
esac
