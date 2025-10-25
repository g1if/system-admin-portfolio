#!/bin/bash
# 📦 Менеджер пакетов и обновлений с автоопределением дистрибутива
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e  # Более совместимая версия

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
BACKUP_DIR="$PROJECT_ROOT/backups/package-backups"
CACHE_DIR="$PROJECT_ROOT/cache/package-cache"
LOG_FILE="$LOG_DIR/package-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$CACHE_DIR" 2>/dev/null || true

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
    echo "📦 ==========================================="
    echo "   МЕНЕДЖЕР ПАКЕТОВ И ОБНОВЛЕНИЙ v1.2"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "${BLUE}📁 $1${NC}"
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

# Определяем дистрибутив и менеджер пакетов
detect_package_manager() {
    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        echo "apt"
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        if command -v dnf >/dev/null 2>&1; then
            echo "dnf"
        else
            echo "yum"
        fi
    elif [ -f /etc/arch-release ]; then
        echo "pacman"
    elif [ -f /etc/alpine-release ]; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# Безопасное сравнение чисел
is_greater_than() {
    local num1=$1
    local num2=$2
    # Убедимся что это числа
    if [[ "$num1" =~ ^[0-9]+$ ]] && [[ "$num2" =~ ^[0-9]+$ ]]; then
        [ "$num1" -gt "$num2" ]
    else
        return 1
    fi
}

# Получение информации о системе
get_system_info() {
    print_section "ИНФОРМАЦИЯ О СИСТЕМЕ"
    
    if [ -f /etc/os-release ]; then
        # Безопасное чтение файла
        if [ -r /etc/os-release ]; then
            OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Unknown")
            OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Unknown")
            echo "  Дистрибутив: $OS_NAME"
            echo "  Версия: $OS_VERSION"
        else
            echo "  Дистрибутив: Не удалось прочитать /etc/os-release"
        fi
    else
        echo "  Дистрибутив: Неизвестно (файл /etc/os-release не найден)"
    fi
    
    local package_manager=$(detect_package_manager)
    echo "  Пакетный менеджер: $package_manager"
    echo "  Архитектура: $(uname -m)"
    echo "  Ядро: $(uname -r)"
}

# Проверка обновлений для APT
check_updates_apt() {
    local detailed=${1:-false}
    
    echo "  Обновление списка пакетов..."
    sudo apt update > /dev/null 2>&1 || true
    
    local update_count=0
    local update_list=$(apt list --upgradable 2>/dev/null || true)
    
    if [ -n "$update_list" ]; then
        # Более безопасный подсчет
        update_count=$(echo "$update_list" | grep -c upgradable 2>/dev/null || echo 0)
        # Вычитаем заголовок если есть обновления
        if [ "$update_count" -gt 0 ] 2>/dev/null; then
            update_count=$((update_count - 1))
        fi
    fi
    
    # Проверяем что update_count число
    if ! [[ "$update_count" =~ ^[0-9]+$ ]]; then
        update_count=0
    fi
    
    if is_greater_than "$update_count" 0; then
        print_status "WARN" "Доступно обновлений: $update_count"
        
        if [ "$detailed" = "true" ]; then
            echo ""
            echo "  📋 Список обновлений:"
            apt list --upgradable 2>/dev/null | grep -v "Listing..." | head -5 | while read -r pkg; do
                if [ -n "$pkg" ]; then
                    echo "    📦 $pkg"
                fi
            done
        fi
    else
        print_status "OK" "Система обновлена"
    fi
}

# Проверка обновлений
check_updates() {
    local manager=$1
    local detailed=${2:-false}
    
    print_section "ПРОВЕРКА ОБНОВЛЕНИЙ"
    
    case $manager in
        "apt")
            check_updates_apt "$detailed"
            ;;
        "yum"|"dnf")
            echo "  Проверка обновлений..."
            local update_count=0
            if [ "$manager" = "dnf" ]; then
                update_count=$(dnf check-update --quiet 2>/dev/null | wc -l 2>/dev/null || echo 0)
            else
                update_count=$(yum check-update --quiet 2>/dev/null | wc -l 2>/dev/null || echo 0)
            fi
            
            if is_greater_than "$update_count" 0; then
                print_status "WARN" "Доступно обновлений: $update_count"
            else
                print_status "OK" "Система обновлена"
            fi
            ;;
        "pacman")
            echo "  Проверка обновлений pacman..."
            if pacman -Qu 2>/dev/null | grep -q .; then
                local update_count=$(pacman -Qu 2>/dev/null | wc -l)
                if is_greater_than "$update_count" 0; then
                    print_status "WARN" "Доступно обновлений: $update_count"
                else
                    print_status "OK" "Система обновлена"
                fi
            else
                print_status "OK" "Система обновлена"
            fi
            ;;
        *)
            print_status "INFO" "Проверка обновлений для $manager не реализована"
            ;;
    esac
}

# Основная функция
main() {
    local package_manager=$(detect_package_manager)
    
    if [ "$package_manager" = "unknown" ]; then
        echo -e "${RED}❌ Не удалось определить пакетный менеджер${NC}"
        exit 1
    fi
    
    print_header
    log "Запуск менеджера пакетов (менеджер: $package_manager)"
    
    get_system_info
    check_updates "$package_manager" "true"
    
    echo ""
    print_section "СТАТИСТИКА ПАКЕТОВ"
    
    case $package_manager in
        "apt")
            local installed_count=$(dpkg -l 2>/dev/null | grep -c '^ii' 2>/dev/null || echo 0)
            echo "  📊 Установлено пакетов: $installed_count"
            ;;
        "yum"|"dnf")
            local installed_count=0
            if [ "$package_manager" = "dnf" ]; then
                installed_count=$(dnf list installed 2>/dev/null | wc -l 2>/dev/null || echo 0)
            else
                installed_count=$(yum list installed 2>/dev/null | wc -l 2>/dev/null || echo 0)
            fi
            echo "  📊 Установлено пакетов: $installed_count"
            ;;
        "pacman")
            local installed_count=$(pacman -Q 2>/dev/null | wc -l 2>/dev/null || echo 0)
            echo "  📊 Установлено пакетов: $installed_count"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ Анализ пакетов завершен${NC}"
    log "Анализ пакетов завершен"
    echo ""
    echo -e "${CYAN}📝 Подробный отчет в логах: $LOG_FILE${NC}"
}

# Простые команды для демонстрации
cmd_update() {
    local package_manager=$(detect_package_manager)
    echo -e "${YELLOW}Запуск обновления для $package_manager...${NC}"
    
    case $package_manager in
        "apt")
            sudo apt update && sudo apt upgrade -y
            ;;
        "yum")
            sudo yum update -y
            ;;
        "dnf")
            sudo dnf upgrade -y
            ;;
        "pacman")
            sudo pacman -Syu --noconfirm
            ;;
    esac
}

cmd_clean() {
    local package_manager=$(detect_package_manager)
    echo -e "${YELLOW}Очистка кэша для $package_manager...${NC}"
    
    case $package_manager in
        "apt")
            sudo apt autoclean && sudo apt autoremove -y
            ;;
        "yum")
            sudo yum clean all
            ;;
        "dnf")
            sudo dnf clean all && sudo dnf autoremove -y
            ;;
        "pacman")
            sudo pacman -Sc --noconfirm
            ;;
    esac
}

cmd_search() {
    if [ -z "${2:-}" ]; then
        echo -e "${RED}❌ Укажите запрос для поиска${NC}"
        exit 1
    fi
    local package_manager=$(detect_package_manager)
    local query="$2"
    
    echo -e "${YELLOW}Поиск пакетов '$query' в $package_manager...${NC}"
    
    case $package_manager in
        "apt")
            apt search "$query" 2>/dev/null | head -10
            ;;
        "yum")
            yum search "$query" 2>/dev/null | head -10
            ;;
        "dnf")
            dnf search "$query" 2>/dev/null | head -10
            ;;
        "pacman")
            pacman -Ss "$query" 2>/dev/null | head -10
            ;;
    esac
}

cmd_help() {
    echo -e "${CYAN}📦 Менеджер пакетов и обновлений v1.2 - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  update    - обновить систему"
    echo "  clean     - очистить кэш пакетов" 
    echo "  search    - поиск пакетов"
    echo "  help      - эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 update"
    echo "  $0 search nginx"
    echo "  $0 clean"
}

# Обработка аргументов
case "${1:-}" in
    "update") cmd_update "$@" ;;
    "clean") cmd_clean "$@" ;;
    "search") cmd_search "$@" ;;
    "help") cmd_help ;;
    *) main ;;
esac
