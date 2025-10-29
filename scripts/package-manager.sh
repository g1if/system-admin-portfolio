#!/bin/bash
# 📦 Продвинутый менеджер пакетов с аналитикой зависимостей и безопасностью
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
BACKUP_DIR="$PROJECT_ROOT/backups/package-backups"
CACHE_DIR="$PROJECT_ROOT/cache/package-cache"
REPORTS_DIR="$PROJECT_ROOT/reports"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$CACHE_DIR" "$REPORTS_DIR"

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
CONFIG_FILE="$CONFIG_DIR/package-manager.conf"
MAIN_LOG="$LOG_DIR/package-manager.log"
CACHE_FILE="$CACHE_DIR/package-cache.db"
BACKUP_LIST="$BACKUP_DIR/backup-list.txt"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "📦 ==========================================="
    echo "   ПРОДВИНУТЫЙ МЕНЕДЖЕР ПАКЕТОВ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📁 $1${NC}"
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

print_debug() {
    echo -e "${ORANGE}🐛 $1${NC}"
}

# Логирование
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
}

# Создание конфигурации
create_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Конфигурация менеджера пакетов v2.0

# Основные настройки
ENABLE_AUTO_BACKUP=true
ENABLE_AUTO_CLEAN=true
BACKUP_BEFORE_UPDATE=true
CONFIRM_ACTIONS=false

# Настройки обновлений
AUTO_UPDATE_INTERVAL=7
CHECK_SECURITY_UPDATES=true
UPDATE_KERNEL=true
UPDATE_CRITICAL_ONLY=false

# Настройки очистки
CLEAN_CACHE_DAYS=7
CLEAN_OLD_KERNELS=true
REMOVE_ORPHANED_PACKAGES=true
REMOVE_UNUSED_DEPENDENCIES=true

# Настройки резервного копирования
BACKUP_RETENTION_DAYS=30
BACKUP_INSTALLED_PACKAGES=true
BACKUP_REPOSITORIES=true
BACKUP_SYSTEM_CONFIGS=true

# Настройки безопасности
VERIFY_PACKAGE_INTEGRITY=true
CHECK_VULNERABILITIES=false
ALLOW_UNSIGNED_PACKAGES=false
ENABLE_PACKAGE_VERIFICATION=true

# Настройки кэширования
ENABLE_CACHING=true
CACHE_TTL=3600

# Списки пакетов
IMPORTANT_PACKAGES=("curl" "wget" "vim" "git" "htop" "tree" "unzip" "tar" "gzip")
EXCLUDE_PACKAGES=("game*" "*-dev" "*-dbg" "*doc*")
SECURITY_PACKAGES=("fail2ban" "ufw" "rkhunter" "clamav")

# Настройки отчетов
GENERATE_REPORTS=true
REPORT_FORMAT="text"
REPORT_RETENTION_DAYS=7

# Настройки репозиториев
ENABLE_THIRD_PARTY_REPOS=false
AUTO_ENABLE_UPDATES=true
VERIFY_REPO_SIGNATURES=true

# Настройки зависимостей
CHECK_BROKEN_DEPENDENCIES=true
FIX_BROKEN_PACKAGES=true
ANALYZE_DEPENDENCY_TREE=true
EOF
    print_success "Конфигурация создана: $CONFIG_FILE"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        ENABLE_AUTO_BACKUP=false
        ENABLE_AUTO_CLEAN=false
        BACKUP_BEFORE_UPDATE=false
        CONFIRM_ACTIONS=false
        AUTO_UPDATE_INTERVAL=7
        CHECK_SECURITY_UPDATES=true
        UPDATE_KERNEL=true
        CLEAN_CACHE_DAYS=7
        CLEAN_OLD_KERNELS=true
        REMOVE_ORPHANED_PACKAGES=true
        BACKUP_RETENTION_DAYS=30
        VERIFY_PACKAGE_INTEGRITY=true
        ENABLE_CACHING=true
        CACHE_TTL=3600
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    # Проверяем наличие основных утилит
    for cmd in awk grep sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Определение менеджера пакетов
detect_package_manager() {
    local cache_key="package_manager"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key"); then
        echo "$cached_value"
        return
    fi
    
    if command -v apt &> /dev/null && [ -f /etc/debian_version ]; then
        echo "apt"
    elif command -v dnf &> /dev/null && [ -f /etc/redhat-release ]; then
        echo "dnf"
    elif command -v yum &> /dev/null && [ -f /etc/redhat-release ]; then
        echo "yum"
    elif command -v pacman &> /dev/null && [ -f /etc/arch-release ]; then
        echo "pacman"
    elif command -v apk &> /dev/null && [ -f /etc/alpine-release ]; then
        echo "apk"
    elif command -v zypper &> /dev/null && [ -f /etc/SuSE-release ]; then
        echo "zypper"
    else
        echo "unknown"
    fi
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

# Получение информации о системе
get_system_info() {
    print_section "ИНФОРМАЦИЯ О СИСТЕМЕ"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "  🖥️  Дистрибутив: $PRETTY_NAME"
        echo "  🏷️  Версия: $VERSION_ID"
    else
        echo "  🖥️  Дистрибутив: Неизвестно"
    fi
    
    local package_manager=$(detect_package_manager)
    echo "  📦 Пакетный менеджер: $package_manager"
    echo "  🏗️  Архитектура: $(uname -m)"
    echo "  🐧 Ядро: $(uname -r)"
    
    # Информация о диске
    local disk_usage=$(df / | awk 'NR==2 {print $5}')
    echo "  💾 Использование диска: $disk_usage"
    
    # Время работы системы
    local uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local days=$(( ${uptime_seconds%.*} / 86400 ))
    echo "  ⏱️  Время работы: ${days} дней"
}

# Проверка обновлений для APT
check_updates_apt() {
    local detailed=${1:-false}
    
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ (APT)"
    
    echo "  🔄 Обновление списка пакетов..."
    if ! sudo apt update > /dev/null 2>&1; then
        print_error "Не удалось обновить список пакетов"
        return 1
    fi
    
    local updates_available=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    # Вычитаем заголовок
    if [ "$updates_available" -gt 0 ]; then
        updates_available=$((updates_available - 1))
    fi
    
    if [ "$updates_available" -gt 0 ]; then
        print_warning "Доступно обновлений: $updates_available"
        
        if [ "$detailed" = "true" ]; then
            echo ""
            echo "  📋 Список обновлений:"
            apt list --upgradable 2>/dev/null | grep -v "Listing..." | head -10 | while read -r pkg; do
                if [ -n "$pkg" ]; then
                    echo "    📦 $pkg"
                fi
            done
        fi
        
        # Проверка обновлений безопасности
        if [ "$CHECK_SECURITY_UPDATES" = "true" ]; then
            local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
            if [ "$security_updates" -gt 0 ]; then
                print_warning "Обновления безопасности: $security_updates"
            fi
        fi
    else
        print_success "Система полностью обновлена"
    fi
    
    return 0
}

# Проверка обновлений для DNF
check_updates_dnf() {
    local detailed=${1:-false}
    
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ (DNF)"
    
    echo "  🔄 Проверка обновлений..."
    local updates_available=$(dnf check-update --quiet 2>/dev/null | wc -l)
    
    if [ "$updates_available" -gt 0 ]; then
        print_warning "Доступно обновлений: $updates_available"
        
        if [ "$detailed" = "true" ]; then
            echo ""
            echo "  📋 Список обновлений:"
            dnf check-update 2>/dev/null | head -10 | while read -r line; do
                if [[ $line != *"Last metadata"* ]] && [[ $line != *"*"* ]] && [ -n "$line" ]; then
                    echo "    📦 $line"
                fi
            done
        fi
    else
        print_success "Система полностью обновлена"
    fi
}

# Проверка обновлений для YUM
check_updates_yum() {
    local detailed=${1:-false}
    
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ (YUM)"
    
    echo "  🔄 Проверка обновлений..."
    local updates_available=$(yum check-update --quiet 2>/dev/null | wc -l)
    
    if [ "$updates_available" -gt 0 ]; then
        print_warning "Доступно обновлений: $updates_available"
        
        if [ "$detailed" = "true" ]; then
            echo ""
            echo "  📋 Список обновлений:"
            yum check-update 2>/dev/null | head -10 | while read -r line; do
                if [[ $line != *"Last metadata"* ]] && [[ $line != *"*"* ]] && [ -n "$line" ]; then
                    echo "    📦 $line"
                fi
            done
        fi
    else
        print_success "Система полностью обновлена"
    fi
}

# Проверка обновлений для Pacman
check_updates_pacman() {
    local detailed=${1:-false}
    
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ (PACMAN)"
    
    echo "  🔄 Проверка обновлений..."
    if pacman -Qu 2>/dev/null | grep -q .; then
        local updates_available=$(pacman -Qu 2>/dev/null | wc -l)
        print_warning "Доступно обновлений: $updates_available"
        
        if [ "$detailed" = "true" ]; then
            echo ""
            echo "  📋 Список обновлений:"
            pacman -Qu 2>/dev/null | head -10 | while read -r pkg; do
                echo "    📦 $pkg"
            done
        fi
    else
        print_success "Система полностью обновлена"
    fi
}

# Общая функция проверки обновлений
check_updates() {
    local package_manager=$(detect_package_manager)
    local detailed=${1:-false}
    
    case $package_manager in
        "apt")
            check_updates_apt "$detailed"
            ;;
        "dnf")
            check_updates_dnf "$detailed"
            ;;
        "yum")
            check_updates_yum "$detailed"
            ;;
        "pacman")
            check_updates_pacman "$detailed"
            ;;
        *)
            print_error "Проверка обновлений для $package_manager не реализована"
            ;;
    esac
}

# Анализ зависимостей
analyze_dependencies() {
    print_section "АНАЛИЗ ЗАВИСИМОСТЕЙ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            echo "  🔍 Проверка целостности зависимостей..."
            if sudo apt check 2>/dev/null; then
                print_success "Зависимости в порядке"
            else
                print_warning "Обнаружены проблемы с зависимостями"
                echo "  💡 Рекомендуется выполнить: sudo apt --fix-broken install"
            fi
            
            # Показать orphaned пакеты
            if [ "$REMOVE_ORPHANED_PACKAGES" = "true" ]; then
                local orphaned=$(deborphan 2>/dev/null | wc -l)
                if [ "$orphaned" -gt 0 ]; then
                    print_warning "Найдено orphaned пакетов: $orphaned"
                fi
            fi
            ;;
        "dnf"|"yum")
            echo "  🔍 Проверка целостности RPM базы данных..."
            if sudo rpm -Va 2>/dev/null | head -5; then
                print_success "RPM база данных в порядке"
            else
                print_warning "Обнаружены проблемы в RPM базе данных"
            fi
            ;;
        *)
            print_info "Анализ зависимостей для $package_manager не реализован"
            ;;
    esac
}

# Резервное копирование установленных пакетов
backup_packages() {
    local backup_name="packages-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_file="$BACKUP_DIR/$backup_name.list"
    
    print_section "РЕЗЕРВНОЕ КОПИРОВАНИЕ ПАКЕТОВ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            dpkg --get-selections > "$backup_file" 2>/dev/null
            ;;
        "dnf"|"yum")
            rpm -qa > "$backup_file" 2>/dev/null
            ;;
        "pacman")
            pacman -Q > "$backup_file" 2>/dev/null
            ;;
        *)
            print_error "Резервное копирование для $package_manager не реализовано"
            return 1
            ;;
    esac
    
    if [ -f "$backup_file" ]; then
        # Добавляем в список резервных копий
        echo "$backup_name|$(date)|$backup_file" >> "$BACKUP_LIST"
        print_success "Резервная копия создана: $backup_file"
        
        # Создаем скрипт для восстановления
        local restore_script="$BACKUP_DIR/restore-$backup_name.sh"
        cat > "$restore_script" << EOF
#!/bin/bash
# Скрипт восстановления пакетов из резервной копии $backup_name
# Создан: $(date)

echo "Восстановление пакетов из $backup_name..."
case "$package_manager" in
    "apt")
        dpkg --set-selections < "$backup_file"
        apt-get dselect-upgrade -y
        ;;
    "dnf")
        dnf install -y \$(cat "$backup_file")
        ;;
    "yum")
        yum install -y \$(cat "$backup_file")
        ;;
    "pacman")
        pacman -S --needed - < "$backup_file"
        ;;
esac
echo "Восстановление завершено!"
EOF
        chmod +x "$restore_script"
        print_success "Создан скрипт восстановления: $restore_script"
    else
        print_error "Не удалось создать резервную копию"
        return 1
    fi
}

# Восстановление пакетов из резервной копии
restore_packages() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        print_error "Укажите файл резервной копии"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    print_section "ВОССТАНОВЛЕНИЕ ПАКЕТОВ ИЗ РЕЗЕРВНОЙ КОПИИ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            sudo dpkg --set-selections < "$backup_file"
            sudo apt-get dselect-upgrade -y
            ;;
        "dnf")
            sudo dnf install -y $(cat "$backup_file")
            ;;
        "yum")
            sudo yum install -y $(cat "$backup_file")
            ;;
        "pacman")
            sudo pacman -S --needed - < "$backup_file"
            ;;
        *)
            print_error "Восстановление для $package_manager не реализовано"
            return 1
            ;;
    esac
    
    print_success "Пакеты восстановлены из: $backup_file"
}

# Установка пакетов
install_packages() {
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        print_error "Не указаны пакеты для установки"
        return 1
    fi
    
    print_section "УСТАНОВКА ПАКЕТОВ: ${packages[*]}"
    
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        backup_packages
    fi
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            sudo apt install -y "${packages[@]}"
            ;;
        "dnf")
            sudo dnf install -y "${packages[@]}"
            ;;
        "yum")
            sudo yum install -y "${packages[@]}"
            ;;
        "pacman")
            sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        *)
            print_error "Установка пакетов для $package_manager не реализована"
            return 1
            ;;
    esac
    
    print_success "Пакеты установлены: ${packages[*]}"
}

# Удаление пакетов
remove_packages() {
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        print_error "Не указаны пакеты для удаления"
        return 1
    fi
    
    print_section "УДАЛЕНИЕ ПАКЕТОВ: ${packages[*]}"
    
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        backup_packages
    fi
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            sudo apt remove -y "${packages[@]}"
            # Удаляем конфигурационные файлы
            if [ "$REMOVE_UNUSED_DEPENDENCIES" = "true" ]; then
                sudo apt autoremove -y
            fi
            ;;
        "dnf")
            sudo dnf remove -y "${packages[@]}"
            ;;
        "yum")
            sudo yum remove -y "${packages[@]}"
            ;;
        "pacman")
            sudo pacman -R --noconfirm "${packages[@]}"
            ;;
        *)
            print_error "Удаление пакетов для $package_manager не реализована"
            return 1
            ;;
    esac
    
    print_success "Пакеты удалены: ${packages[*]}"
}

# Очистка кэша пакетов
clean_cache() {
    print_section "ОЧИСТКА КЭША ПАКЕТОВ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            sudo apt autoclean
            sudo apt autoremove -y
            ;;
        "dnf")
            sudo dnf clean all
            sudo dnf autoremove -y
            ;;
        "yum")
            sudo yum clean all
            ;;
        "pacman")
            sudo pacman -Sc --noconfirm
            ;;
        *)
            print_error "Очистка кэша для $package_manager не реализована"
            return 1
            ;;
    esac
    
    print_success "Кэш пакетов очищен"
}

# Поиск пакетов
search_packages() {
    local query=$1
    
    if [ -z "$query" ]; then
        print_error "Укажите запрос для поиска"
        return 1
    fi
    
    print_section "ПОИСК ПАКЕТОВ: $query"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            apt search "$query" 2>/dev/null | head -20
            ;;
        "dnf")
            dnf search "$query" 2>/dev/null | head -20
            ;;
        "yum")
            yum search "$query" 2>/dev/null | head -20
            ;;
        "pacman")
            pacman -Ss "$query" 2>/dev/null | head -20
            ;;
        *)
            print_error "Поиск пакетов для $package_manager не реализован"
            return 1
            ;;
    esac
}

# Показать информацию о пакете
show_package_info() {
    local package=$1
    
    if [ -z "$package" ]; then
        print_error "Укажите пакет для просмотра информации"
        return 1
    fi
    
    print_section "ИНФОРМАЦИЯ О ПАКЕТЕ: $package"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            apt show "$package" 2>/dev/null
            ;;
        "dnf")
            dnf info "$package" 2>/dev/null
            ;;
        "yum")
            yum info "$package" 2>/dev/null
            ;;
        "pacman")
            pacman -Qi "$package" 2>/dev/null || pacman -Si "$package" 2>/dev/null
            ;;
        *)
            print_error "Просмотр информации о пакете для $package_manager не реализован"
            return 1
            ;;
    esac
}

# Обновление системы
update_system() {
    print_section "ОБНОВЛЕНИЕ СИСТЕМЫ"
    
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        backup_packages
    fi
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            sudo apt update
            sudo apt upgrade -y
            if [ "$UPDATE_KERNEL" = "true" ]; then
                sudo apt full-upgrade -y
            fi
            ;;
        "dnf")
            sudo dnf upgrade -y
            ;;
        "yum")
            sudo yum update -y
            ;;
        "pacman")
            sudo pacman -Syu --noconfirm
            ;;
        *)
            print_error "Обновление системы для $package_manager не реализовано"
            return 1
            ;;
    esac
    
    print_success "Система обновлена"
}

# Просмотр истории изменений
show_history() {
    print_section "ИСТОРИЯ ИЗМЕНЕНИЙ ПАКЕТОВ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            grep -h "Status: install" /var/log/dpkg.log* | tail -10
            ;;
        "dnf"|"yum")
            sudo tail -10 /var/log/dnf.log /var/log/yum.log 2>/dev/null
            ;;
        "pacman")
            grep -h "installed" /var/log/pacman.log | tail -10
            ;;
        *)
            print_error "Просмотр истории для $package_manager не реализован"
            return 1
            ;;
    esac
}

# Анализ использования пакетов
analyze_package_usage() {
    print_section "АНАЛИЗ ИСПОЛЬЗОВАНИЯ ПАКЕТОВ"
    
    local package_manager=$(detect_package_manager)
    
    case $package_manager in
        "apt")
            echo "  📊 Статистика пакетов:"
            local total_packages=$(dpkg -l | grep -c '^ii')
            local auto_installed=$(apt-mark showauto | wc -l)
            local manually_installed=$(apt-mark showmanual | wc -l)
            
            echo "    📦 Всего пакетов: $total_packages"
            echo "    🤖 Автоматически установлено: $auto_installed"
            echo "    👤 Вручную установлено: $manually_installed"
            
            # Размер установленных пакетов
            if command -v dpkg-query &> /dev/null; then
                local total_size=$(dpkg-query -W -f='${Installed-Size}\t${Package}\n' | awk '{sum+=$1} END {print sum/1024}')
                echo "    💾 Общий размер: ${total_size%.*} MB"
            fi
            ;;
        *)
            print_info "Анализ использования для $package_manager не реализован"
            ;;
    esac
}

# Генерация отчета
generate_report() {
    local report_file="$REPORTS_DIR/package-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "ГЕНЕРАЦИЯ ОТЧЕТА"
    
    print_header > "$report_file"
    echo "📅 Отчет создан: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    get_system_info >> "$report_file"
    echo "" >> "$report_file"
    check_updates true >> "$report_file"
    echo "" >> "$report_file"
    analyze_dependencies >> "$report_file"
    echo "" >> "$report_file"
    analyze_package_usage >> "$report_file"
    
    print_success "Отчет сохранен: $report_file"
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "update")
            update_system
            ;;
        "install")
            shift
            install_packages "$@"
            ;;
        "remove")
            shift
            remove_packages "$@"
            ;;
        "search")
            search_packages "${2:-}"
            ;;
        "info")
            show_package_info "${2:-}"
            ;;
        "clean")
            clean_cache
            ;;
        "backup")
            backup_packages
            ;;
        "restore")
            restore_packages "${2:-}"
            ;;
        "history")
            show_history
            ;;
        "analyze")
            analyze_dependencies
            analyze_package_usage
            ;;
        "report")
            generate_report
            ;;
        "config")
            create_config
            ;;
        "check")
            check_updates true
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  update              - Обновить систему"
            echo "  install <пакеты>    - Установить пакеты"
            echo "  remove <пакеты>     - Удалить пакеты"
            echo "  search <запрос>     - Поиск пакетов"
            echo "  info <пакет>        - Информация о пакете"
            echo "  clean               - Очистка кэша пакетов"
            echo "  backup              - Резервное копирование пакетов"
            echo "  restore <файл>      - Восстановление пакетов"
            echo "  history             - История изменений"
            echo "  analyze             - Анализ зависимостей и использования"
            echo "  report              - Генерация отчета"
            echo "  config              - Создать конфигурацию"
            echo "  check               - Проверить обновления"
            echo "  help                - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 update"
            echo "  $0 install nginx mysql"
            echo "  $0 search python3"
            echo "  $0 info curl"
            echo "  $0 backup"
            echo "  $0 restore /path/to/backup.list"
            echo "  $0 analyze"
            echo "  $0 report"
            ;;
        *)
            print_header
            get_system_info
            check_updates true
            analyze_dependencies
            analyze_package_usage
            ;;
    esac
}

# Инициализация
log_message "INFO" "Запуск менеджера пакетов"
main "$@"
log_message "INFO" "Завершение работы"
