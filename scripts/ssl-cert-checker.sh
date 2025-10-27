#!/bin/bash
# 🔐 Мониторинг SSL сертификатов доменов
# Автор: g1if

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
SSL_DIR="$PROJECT_ROOT/ssl-reports"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$SSL_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Конфигурация
SSL_CONFIG="$CONFIG_DIR/ssl-domains.conf"
SSL_REPORT="$SSL_DIR/ssl-report-$(date +%Y%m%d).log"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🔐 ==========================================="
    echo "   МОНИТОРИНГ SSL СЕРТИФИКАТОВ v1.0"
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды:"
    echo "  check      - Проверить все домены"
    echo "  monitor    - Мониторинг с оповещениями"
    echo "  add        - Добавить домен для мониторинга"
    echo "  list       - Список отслеживаемых доменов"
    echo "  report     - Создать отчет"
    echo "  config     - Создать конфигурацию"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 check"
    echo "  $0 add google.com"
    echo "  $0 monitor"
}

# Создание конфигурации
create_config() {
    cat > "$SSL_CONFIG" << 'EOF'
# Список доменов для мониторинга SSL сертификатов
# Формат: domain[:port] (порт по умолчанию: 443)

DOMAINS=(
    "google.com"
    "github.com"
    "ubuntu.com"
    "microsoft.com"
    "letsencrypt.org"
)

# Пороговые значения (в днях)
WARNING_DAYS=30
CRITICAL_DAYS=7

# Проверять каждые (часов) в режиме мониторинга
CHECK_INTERVAL_HOURS=24
EOF
    print_success "Конфигурация создана: $SSL_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$SSL_CONFIG" ]; then
        source "$SSL_CONFIG"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        DOMAINS=("google.com" "github.com")
        WARNING_DAYS=30
        CRITICAL_DAYS=7
        CHECK_INTERVAL_HOURS=24
    fi
}

# Проверка SSL сертификата
check_ssl_cert() {
    local domain=$1
    local port=${2:-443}
    
    # Разделяем домен и порт если указано в формате domain:port
    if [[ $domain == *":"* ]]; then
        port=${domain#*:}
        domain=${domain%:*}
    fi
    
    echo -e "\n${PURPLE}🔍 Проверка: $domain:$port${NC}"
    
    # Используем openssl для проверки сертификата
    local cert_info
    cert_info=$(timeout 10s openssl s_client -connect "$domain:$port" -servername "$domain" -showcerts </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || true)
    
    if [ -z "$cert_info" ]; then
        print_error "Не удалось получить SSL сертификат"
        return 1
    fi
    
    # Извлекаем даты
    local not_before=$(echo "$cert_info" | grep "notBefore" | cut -d= -f2-)
    local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2-)
    
    # Конвертируем в timestamp
    local expire_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    
    if [ "$expire_timestamp" -eq 0 ]; then
        print_error "Не удалось проанализировать дату истечения"
        return 1
    fi
    
    # Вычисляем оставшиеся дни
    local seconds_left=$((expire_timestamp - current_timestamp))
    local days_left=$((seconds_left / 86400))
    
    # Дополнительная информация о сертификате
    local cert_subject=$(timeout 10s openssl s_client -connect "$domain:$port" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | cut -d= -f2- || echo "N/A")
    local cert_issuer=$(timeout 10s openssl s_client -connect "$domain:$port" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | cut -d= -f2- || echo "N/A")
    
    echo "  📄 Сертификат: $cert_subject"
    echo "  🏢 Издатель: $cert_issuer"
    echo "  📅 Выдан: $not_before"
    echo "  📅 Истекает: $not_after"
    echo -n "  ⏰ Осталось дней: "
    
    if [ "$days_left" -lt 0 ]; then
        print_error "ПРОСРОЧЕН ($(( -days_left )) дней назад)"
        echo "    🚨 НЕМЕДЛЕННО ЗАМЕНИТЕ СЕРТИФИКАТ!"
    elif [ "$days_left" -le "$CRITICAL_DAYS" ]; then
        print_error "$days_left (КРИТИЧЕСКИ)"
        echo "    ⚠️  Срочно замените сертификат!"
    elif [ "$days_left" -le "$WARNING_DAYS" ]; then
        print_warning "$days_left (ПРЕДУПРЕЖДЕНИЕ)"
        echo "    💡 Запланируйте замену сертификата"
    else
        print_success "$days_left"
        echo "    ✅ Всё в порядке"
    fi
    
    # Логируем результат
    local status
    if [ "$days_left" -lt 0 ]; then
        status="EXPIRED"
    elif [ "$days_left" -le "$CRITICAL_DAYS" ]; then
        status="CRITICAL"
    elif [ "$days_left" -le "$WARNING_DAYS" ]; then
        status="WARNING"
    else
        status="OK"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $domain:$port | $status | $days_left дней | до $not_after" >> "$SSL_REPORT"
    
    return 0
}

# Проверка всех доменов
check_all_domains() {
    print_section "ПРОВЕРКА SSL СЕРТИФИКАТОВ"
    
    local total=0
    local problems=0
    
    for domain_entry in "${DOMAINS[@]}"; do
        if check_ssl_cert "$domain_entry"; then
            ((total++))
        else
            ((total++))
            ((problems++))
        fi
    done
    
    echo ""
    echo "📈 ИТОГИ:"
    echo "  📊 Проверено доменов: $total"
    echo "  ⚠️  Проблемных: $problems"
    echo "  📁 Отчет: $SSL_REPORT"
}

# Добавление домена
add_domain() {
    local domain=$1
    local port=${2:-443}
    
    if [ -z "$domain" ]; then
        print_error "Укажите домен для добавления"
        echo "Использование: $0 add <domain> [port]"
        return 1
    fi
    
    # Проверяем валидность домена
    if ! [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Неверный формат домена: $domain"
        return 1
    fi
    
    # Добавляем домен в конфигурацию
    if ! grep -q "\"$domain\"" "$SSL_CONFIG" 2>/dev/null; then
        # Убираем закрывающую скобку, добавляем домен и снова добавляем скобку
        sed -i "/^DOMAINS=(/a \\\"$domain:$port\\\"" "$SSL_CONFIG"
        print_success "Домен $domain:$port добавлен в мониторинг"
    else
        print_warning "Домен $domain уже есть в списке мониторинга"
    fi
}

# Список доменов
list_domains() {
    print_section "ОТСЛЕЖИВАЕМЫЕ ДОМЕНЫ"
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        echo "  ℹ️  Домены не настроены"
        echo "  💡 Используйте: $0 add <domain>"
        return
    fi
    
    for domain_entry in "${DOMAINS[@]}"; do
        echo "  🌐 $domain_entry"
    done
    echo ""
    echo "  Всего доменов: ${#DOMAINS[@]}"
}

# Режим мониторинга
monitor_mode() {
    print_header
    echo "  🔍 ЗАПУСК МОНИТОРИНГА SSL СЕРТИФИКАТОВ"
    echo "  ⏰ Интервал проверки: $CHECK_INTERVAL_HOURS часов"
    echo "  📊 Отслеживаемые домены: ${#DOMAINS[@]}"
    echo ""
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    while true; do
        local check_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo "======= ПРОВЕРКА ($check_time) ======="
        check_all_domains
        echo "====================================="
        echo ""
        echo "⏳ Следующая проверка через $CHECK_INTERVAL_HOURS часов..."
        sleep $((CHECK_INTERVAL_HOURS * 3600))
    done
}

# Создание отчета
generate_report() {
    print_section "ОТЧЕТ ПО SSL СЕРТИФИКАТАМ"
    
    if [ -f "$SSL_REPORT" ]; then
        echo "📋 Последние проверки:"
        tail -20 "$SSL_REPORT"
        echo ""
        echo "📊 Статистика:"
        local total_checks=$(grep -c "|" "$SSL_REPORT" 2>/dev/null || echo "0")
        local expired=$(grep -c "EXPIRED" "$SSL_REPORT" 2>/dev/null || echo "0")
        local critical=$(grep -c "CRITICAL" "$SSL_REPORT" 2>/dev/null || echo "0")
        local warning=$(grep -c "WARNING" "$SSL_REPORT" 2>/dev/null || echo "0")
        
        echo "  Всего проверок: $total_checks"
        echo "  🔴 Просрочено: $expired"
        echo "  🟠 Критических: $critical"
        echo "  🟡 Предупреждений: $warning"
        echo "  🟢 Исправных: $((total_checks - expired - critical - warning))"
    else
        echo "  ℹ️  Отчеты не найдены"
        echo "  💡 Запустите проверку: $0 check"
    fi
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "check")
            print_header
            check_all_domains
            ;;
        "monitor")
            monitor_mode
            ;;
        "add")
            add_domain "$2" "$3"
            ;;
        "list")
            print_header
            list_domains
            ;;
        "report")
            print_header
            generate_report
            ;;
        "config")
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

# Проверяем наличие openssl
if ! command -v openssl >/dev/null 2>&1; then
    print_error "OpenSSL не установлен. Установите: sudo apt install openssl"
    exit 1
fi

main "$@"
