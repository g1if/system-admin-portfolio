#!/bin/bash
# 🔐 Продвинутый мониторинг SSL/TLS сертификатов доменов
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
SSL_DIR="$PROJECT_ROOT/ssl-reports"
REPORTS_DIR="$PROJECT_ROOT/reports"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$SSL_DIR" "$REPORTS_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Конфигурация
SSL_CONFIG="$CONFIG_DIR/ssl-domains.conf"
SSL_REPORT="$SSL_DIR/ssl-report-$(date +%Y%m%d).log"
MAIN_LOG="$LOG_DIR/ssl-checker.log"

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    for cmd in openssl curl date grep awk sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Логирование
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
}

print_header() {
    echo -e "${CYAN}"
    echo "🔐 ==========================================="
    echo "   ПРОДВИНУТЫЙ SSL МОНИТОРИНГ v2.0"
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

print_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Создание конфигурации
create_config() {
    cat > "$SSL_CONFIG" << 'EOF'
# Конфигурация SSL мониторинга v2.0

# Список доменов для мониторинга SSL сертификатов
# Формат: domain[:port] (порт по умолчанию: 443)

DOMAINS=(
    "google.com"
    "github.com:443"
    "ubuntu.com"
    "microsoft.com:443"
    "letsencrypt.org"
    "cloudflare.com"
)

# Пороговые значения (в днях)
WARNING_DAYS=30
CRITICAL_DAYS=7
EXPIRY_ALERT_DAYS=60

# Настройки проверки
CHECK_INTERVAL_HOURS=24
TIMEOUT=10
VERIFY_CHAIN=true
CHECK_OCSP=false
CHECK_CIPHERS=true

# Настройки оповещений
ALERT_ENABLED=true
ALERT_METHODS=("console" "log")  # console, log, email, telegram
ALERT_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Настройки отчетов
REPORT_FORMAT="text"  # text, csv, json
REPORT_RETENTION_DAYS=30
AUTO_GENERATE_REPORT=true

# Дополнительные настройки
ENABLE_DNS_CHECK=true
ENABLE_HTTP_CHECK=true
CHECK_ALTERNATIVE_NAMES=true
EOF
    print_success "Конфигурация создана: $SSL_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$SSL_CONFIG" ]; then
        source "$SSL_CONFIG"
        log "INFO" "Конфигурация загружена из $SSL_CONFIG"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        DOMAINS=("google.com" "github.com")
        WARNING_DAYS=30
        CRITICAL_DAYS=7
        EXPIRY_ALERT_DAYS=60
        CHECK_INTERVAL_HOURS=24
        TIMEOUT=10
        ALERT_ENABLED=true
        ALERT_METHODS=("console" "log")
    fi
}

# Отправка оповещений
send_alert() {
    local level=$1
    local message=$2
    local domain=${3:-""}
    
    if [ "$ALERT_ENABLED" != "true" ]; then
        return
    fi
    
    local full_message="[$level] $message"
    if [ -n "$domain" ]; then
        full_message="[$level] Домен $domain: $message"
    fi
    
    # Логирование всегда
    log "$level" "$message"
    
    # Console оповещения
    if [[ " ${ALERT_METHODS[@]} " =~ " console " ]]; then
        case $level in
            "CRITICAL") print_error "$message" ;;
            "WARNING") print_warning "$message" ;;
            "INFO") print_info "$message" ;;
            *) echo "$message" ;;
        esac
    fi
}

# Проверка доступности домена
check_domain_availability() {
    local domain=$1
    local port=$2
    
    # Проверка DNS
    if [ "$ENABLE_DNS_CHECK" = "true" ]; then
        if ! nslookup "$domain" &> /dev/null; then
            echo "DNS_FAIL"
            return 1
        fi
    fi
    
    # Проверка TCP соединения
    if ! timeout "$TIMEOUT" bash -c "echo > /dev/tcp/$domain/$port" 2>/dev/null; then
        echo "TCP_FAIL"
        return 1
    fi
    
    echo "AVAILABLE"
    return 0
}

# Получение детальной информации о сертификате
get_certificate_details() {
    local domain=$1
    local port=$2
    
    local cert_info
    cert_info=$(timeout "$TIMEOUT" openssl s_client -connect "$domain:$port" -servername "$domain" -showcerts </dev/null 2>/dev/null)
    
    if [ -z "$cert_info" ]; then
        return 1
    fi
    
    # Основная информация
    local subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')
    local issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')
    local dates=$(echo "$cert_info" | openssl x509 -noout -dates 2>/dev/null)
    local not_before=$(echo "$dates" | grep "notBefore" | cut -d= -f2-)
    local not_after=$(echo "$dates" | grep "notAfter" | cut -d= -f2-)
    
    # Дополнительная информация
    local serial=$(echo "$cert_info" | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
    local sig_algo=$(echo "$cert_info" | openssl x509 -noout -signature_algorithm 2>/dev/null)
    local pubkey_algo=$(echo "$cert_info" | openssl x509 -noout -pubkey 2>/dev/null | openssl pkey -pubin -text 2>/dev/null | grep "Public Key Algorithm" | head -1 | awk '{print $NF}')
    local key_size=$(echo "$cert_info" | openssl x509 -noout -pubkey 2>/dev/null | openssl pkey -pubin -text 2>/dev/null | grep "Public-Key:" | awk '{print $2}')
    local san=$(echo "$cert_info" | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g' | tr -d ' ' || echo "N/A")
    
    # Конвертируем даты в timestamp
    local expire_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local seconds_left=$((expire_timestamp - current_timestamp))
    local days_left=$((seconds_left / 86400))
    
    # Проверка цепочки сертификатов
    local chain_status="UNKNOWN"
    if [ "$VERIFY_CHAIN" = "true" ]; then
        if echo "$cert_info" | openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt 2>/dev/null | grep -q "OK"; then
            chain_status="VALID"
        else
            chain_status="INVALID"
        fi
    fi
    
    # Проверка поддерживаемых шифров
    local ciphers="N/A"
    if [ "$CHECK_CIPHERS" = "true" ]; then
        ciphers=$(timeout "$TIMEOUT" openssl s_client -connect "$domain:$port" -servername "$domain" -cipher ALL </dev/null 2>/dev/null | grep "Cipher" | head -1 | awk '{print $3}' || echo "N/A")
    fi
    
    # Формируем JSON с результатами
    cat << EOF
{
    "domain": "$domain",
    "port": "$port",
    "subject": "$subject",
    "issuer": "$issuer",
    "serial": "$serial",
    "signature_algorithm": "$sig_algo",
    "public_key_algorithm": "$pubkey_algo",
    "key_size": "$key_size",
    "not_before": "$not_before",
    "not_after": "$not_after",
    "days_left": "$days_left",
    "san": "$san",
    "chain_status": "$chain_status",
    "ciphers": "$ciphers",
    "timestamp": "$(date -Iseconds)"
}
EOF
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
    
    echo -e "\n${MAGENTA}🔍 Проверка: $domain:$port${NC}"
    
    # Проверяем доступность домена
    local availability
    availability=$(check_domain_availability "$domain" "$port")
    
    case $availability in
        "DNS_FAIL")
            print_error "DNS запрос не удался"
            send_alert "ERROR" "DNS запрос не удался для $domain" "$domain"
            return 1
            ;;
        "TCP_FAIL")
            print_error "Не удалось установить TCP соединение"
            send_alert "ERROR" "Не удалось установить TCP соединение с $domain:$port" "$domain"
            return 1
            ;;
    esac
    
    # Получаем детальную информацию о сертификате
    local cert_details
    cert_details=$(get_certificate_details "$domain" "$port")
    
    if [ -z "$cert_details" ]; then
        print_error "Не удалось получить SSL сертификат"
        send_alert "ERROR" "Не удалось получить SSL сертификат для $domain" "$domain"
        return 1
    fi
    
    # Парсим JSON
    local subject=$(echo "$cert_details" | grep '"subject"' | cut -d'"' -f4)
    local issuer=$(echo "$cert_details" | grep '"issuer"' | cut -d'"' -f4)
    local not_before=$(echo "$cert_details" | grep '"not_before"' | cut -d'"' -f4)
    local not_after=$(echo "$cert_details" | grep '"not_after"' | cut -d'"' -f4)
    local days_left=$(echo "$cert_details" | grep '"days_left"' | cut -d'"' -f4)
    local san=$(echo "$cert_details" | grep '"san"' | cut -d'"' -f4)
    local chain_status=$(echo "$cert_details" | grep '"chain_status"' | cut -d'"' -f4)
    local key_size=$(echo "$cert_details" | grep '"key_size"' | cut -d'"' -f4)
    local ciphers=$(echo "$cert_details" | grep '"ciphers"' | cut -d'"' -f4)
    
    # Выводим информацию
    echo "  📄 Сертификат: $(echo "$subject" | cut -d'=' -f2- | cut -d',' -f1)"
    echo "  🏢 Издатель: $(echo "$issuer" | cut -d'=' -f2- | cut -d',' -f1)"
    echo "  🔑 Размер ключа: $key_size бит"
    echo "  📅 Выдан: $not_before"
    echo "  📅 Истекает: $not_after"
    
    if [ "$san" != "N/A" ] && [ "$CHECK_ALTERNATIVE_NAMES" = "true" ]; then
        echo "  🌐 Альтернативные имена: $san"
    fi
    
    if [ "$chain_status" != "UNKNOWN" ]; then
        echo -n "  🔗 Цепочка сертификатов: "
        if [ "$chain_status" = "VALID" ]; then
            print_success "ВАЛИДНА"
        else
            print_error "НЕВАЛИДНА"
        fi
    fi
    
    if [ "$ciphers" != "N/A" ]; then
        echo "  🛡️  Активный шифр: $ciphers"
    fi
    
    echo -n "  ⏰ Осталось дней: "
    
    local status="OK"
    if [ "$days_left" -lt 0 ]; then
        print_error "ПРОСРОЧЕН ($(( -days_left )) дней назад)"
        echo "    🚨 НЕМЕДЛЕННО ЗАМЕНИТЕ СЕРТИФИКАТ!"
        status="EXPIRED"
        send_alert "CRITICAL" "Сертификат ПРОСРОЧЕН! $domain" "$domain"
    elif [ "$days_left" -le "$CRITICAL_DAYS" ]; then
        print_error "$days_left (КРИТИЧЕСКИ)"
        echo "    ⚠️  Срочно замените сертификат!"
        status="CRITICAL"
        send_alert "CRITICAL" "Сертификат истекает через $days_left дней: $domain" "$domain"
    elif [ "$days_left" -le "$WARNING_DAYS" ]; then
        print_warning "$days_left (ПРЕДУПРЕЖДЕНИЕ)"
        echo "    💡 Запланируйте замену сертификата"
        status="WARNING"
        send_alert "WARNING" "Сертификат истекает через $days_left дней: $domain" "$domain"
    elif [ "$days_left" -le "$EXPIRY_ALERT_DAYS" ]; then
        print_info "$days_left"
        echo "    📝 Скоро истекает, рекомендуется проверить"
        status="INFO"
    else
        print_success "$days_left"
        echo "    ✅ Всё в порядке"
    fi
    
    # Логируем результат
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $domain:$port | $status | $days_left дней | до $not_after | Цепочка: $chain_status" >> "$SSL_REPORT"
    
    return 0
}

# Проверка всех доменов
check_all_domains() {
    print_section "ПРОВЕРКА SSL СЕРТИФИКАТОВ"
    
    local total=0
    local problems=0
    local expired=0
    local critical=0
    local warning=0
    
    for domain_entry in "${DOMAINS[@]}"; do
        if check_ssl_cert "$domain_entry"; then
            ((total++))
        else
            ((total++))
            ((problems++))
        fi
        
        # Статистика по статусам
        case $? in
            2) ((expired++)) ;;
            3) ((critical++)) ;;
            4) ((warning++)) ;;
        esac
        
        # Небольшая пауза между проверками
        sleep 1
    done
    
    echo ""
    echo "📈 ИТОГИ ПРОВЕРКИ:"
    echo "  📊 Проверено доменов: $total"
    echo "  🔴 Просрочено: $expired"
    echo "  🟠 Критических: $critical"
    echo "  🟡 Предупреждений: $warning"
    echo "  🟢 Исправных: $((total - expired - critical - warning))"
    echo "  📁 Отчет: $SSL_REPORT"
    
    log "INFO" "Проверка завершена. Всего: $total, Проблемы: $problems"
    
    return $problems
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
    
    # Проверяем существование конфигурационного файла
    if [ ! -f "$SSL_CONFIG" ]; then
        create_config
    fi
    
    # Добавляем домен в конфигурацию
    local domain_entry="$domain:$port"
    if ! grep -q "\"$domain:\?$port\\?\"" "$SSL_CONFIG" 2>/dev/null; then
        # Более безопасное добавление в массив
        sed -i "/^DOMAINS=(/a \\    \"$domain_entry\"" "$SSL_CONFIG"
        print_success "Домен $domain_entry добавлен в мониторинг"
        log "INFO" "Добавлен домен: $domain_entry"
    else
        print_warning "Домен $domain уже есть в списке мониторинга"
    fi
}

# Удаление домена
remove_domain() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        print_error "Укажите домен для удаления"
        echo "Использование: $0 remove <domain>"
        return 1
    fi
    
    if [ ! -f "$SSL_CONFIG" ]; then
        print_error "Конфигурационный файл не найден"
        return 1
    fi
    
    # Удаляем домен из конфигурации
    if sed -i "/\"$domain\"/d" "$SSL_CONFIG" 2>/dev/null; then
        print_success "Домен $domain удален из мониторинга"
        log "INFO" "Удален домен: $domain"
    else
        print_error "Не удалось удалить домен $domain"
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
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_header
    echo "  🔍 ЗАПУСК МОНИТОРИНГА SSL СЕРТИФИКАТОВ"
    echo "  ⏰ Интервал проверки: $CHECK_INTERVAL_HOURS часов"
    echo "  📊 Отслеживаемые домены: ${#DOMAINS[@]}"
    echo "  🚨 Пороги: $WARNING_DAYS дней (предупреждение), $CRITICAL_DAYS дней (критично)"
    echo ""
    echo "  Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        local check_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo "======= ПРОВЕРКА #$counter ($check_time) ======="
        check_all_domains
        echo "=============================================="
        echo ""
        
        if [ $counter -eq 1 ]; then
            echo "⏳ Следующая проверка через $CHECK_INTERVAL_HOURS часов..."
        fi
        
        sleep $((CHECK_INTERVAL_HOURS * 3600))
    done
}

# Генерация расширенного отчета
generate_report() {
    print_section "РАСШИРЕННЫЙ ОТЧЕТ ПО SSL СЕРТИФИКАТАМ"
    
    local report_file="$REPORTS_DIR/ssl-detailed-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "ДЕТАЛЬНЫЙ ОТЧЕТ SSL СЕРТИФИКАТОВ"
        echo "Сгенерирован: $(date)"
        echo "==========================================="
        echo ""
        
        if [ -f "$SSL_REPORT" ]; then
            echo "ПОСЛЕДНИЕ ПРОВЕРКИ:"
            echo "-----------------"
            tail -10 "$SSL_REPORT" | while read -r line; do
                echo "$line"
            done
            echo ""
            
            echo "СТАТИСТИКА:"
            echo "----------"
            local total_checks=$(grep -c "|" "$SSL_REPORT" 2>/dev/null || echo "0")
            local expired=$(grep -c "EXPIRED" "$SSL_REPORT" 2>/dev/null || echo "0")
            local critical=$(grep -c "CRITICAL" "$SSL_REPORT" 2>/dev/null || echo "0")
            local warning=$(grep -c "WARNING" "$SSL_REPORT" 2>/dev/null || echo "0")
            local info=$(grep -c "INFO" "$SSL_REPORT" 2>/dev/null || echo "0")
            local ok=$(grep -c "OK" "$SSL_REPORT" 2>/dev/null || echo "0")
            
            echo "Всего проверок: $total_checks"
            echo "🔴 Просрочено: $expired"
            echo "🟠 Критических: $critical"
            echo "🟡 Предупреждений: $warning"
            echo "🔵 Информационных: $info"
            echo "🟢 Исправных: $ok"
            echo ""
            
            # Находим ближайшие истекающие сертификаты
            echo "БЛИЖАЙШИЕ ИСТЕЧЕНИЯ:"
            echo "-------------------"
            grep -v "EXPIRED" "$SSL_REPORT" | sort -t'|' -k4 -n | head -5 | while read -r line; do
                local domain=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
                local days=$(echo "$line" | cut -d'|' -f4 | tr -d ' ' | cut -d' ' -f1)
                local expiry=$(echo "$line" | cut -d'|' -f5 | cut -d':' -f2-)
                echo "  $domain: $days дней (до $expiry)"
            done
        else
            echo "Отчеты не найдены"
            echo "Запустите проверку: $0 check"
        fi
        
    } > "$report_file"
    
    print_success "Расширенный отчет сохранен: $report_file"
    cat "$report_file"
}

# Быстрая проверка одного домена
quick_check() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        print_error "Укажите домен для проверки"
        echo "Использование: $0 quick <domain>"
        return 1
    fi
    
    print_section "БЫСТРАЯ ПРОВЕРКА: $domain"
    check_ssl_cert "$domain"
}

# Валидация конфигурации
validate_config() {
    print_section "ВАЛИДАЦИЯ КОНФИГУРАЦИИ"
    
    if [ ! -f "$SSL_CONFIG" ]; then
        print_error "Конфигурационный файл не найден"
        return 1
    fi
    
    # Проверяем синтаксис конфигурации
    if bash -n "$SSL_CONFIG" 2>/dev/null; then
        print_success "Синтаксис конфигурации корректен"
    else
        print_error "Ошибка синтаксиса в конфигурационном файле"
        return 1
    fi
    
    # Проверяем наличие доменов
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        print_warning "Нет доменов для мониторинга"
    else
        print_success "Настроено доменов: ${#DOMAINS[@]}"
    fi
    
    # Проверяем пороговые значения
    if [ "$WARNING_DAYS" -le "$CRITICAL_DAYS" ]; then
        print_error "WARNING_DAYS ($WARNING_DAYS) должен быть больше CRITICAL_DAYS ($CRITICAL_DAYS)"
        return 1
    fi
    
    print_success "Конфигурация валидна"
    return 0
}

show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  check              - Проверить все домены"
    echo "  monitor            - Мониторинг с оповещениями"
    echo "  quick <domain>     - Быстрая проверка одного домена"
    echo "  add <domain> [port]- Добавить домен для мониторинга"
    echo "  remove <domain>    - Удалить домен из мониторинга"
    echo "  list               - Список отслеживаемых доменов"
    echo "  report             - Создать детальный отчет"
    echo "  config             - Создать конфигурацию"
    echo "  validate           - Проверить конфигурацию"
    echo "  help               - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 check"
    echo "  $0 add example.com 443"
    echo "  $0 remove olddomain.com"
    echo "  $0 quick google.com"
    echo "  $0 monitor"
    echo "  $0 validate"
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
        "quick")
            quick_check "$2"
            ;;
        "add")
            add_domain "$2" "$3"
            ;;
        "remove")
            remove_domain "$2"
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
        "validate")
            print_header
            validate_config
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
