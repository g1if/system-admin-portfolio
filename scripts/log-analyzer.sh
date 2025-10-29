#!/bin/bash
# 📊 Продвинутый анализатор системных логов с AI-подобным анализом
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
REPORT_DIR="$PROJECT_ROOT/reports"
CACHE_DIR="$PROJECT_ROOT/cache"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORT_DIR" "$CACHE_DIR"

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
CONFIG_FILE="$CONFIG_DIR/log-analyzer.conf"
MAIN_LOG="$LOG_DIR/log-analyzer.log"
PATTERNS_FILE="$CONFIG_DIR/log-patterns.conf"
CACHE_FILE="$CACHE_DIR/log-cache.db"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "📊 ==========================================="
    echo "   ПРОДВИНУТЫЙ АНАЛИЗАТОР ЛОГОВ v2.0"
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
# Конфигурация анализатора логов v2.0

# Системные логи для мониторинга
LOG_FILES=(
    "/var/log/syslog"
    "/var/log/auth.log" 
    "/var/log/kern.log"
    "/var/log/dpkg.log"
    "/var/log/nginx/access.log"
    "/var/log/nginx/error.log"
    "/var/log/mysql/error.log"
    "/var/log/apache2/access.log"
    "/var/log/apache2/error.log"
)

# Дополнительные логи (добавляются если существуют)
EXTRA_LOGS=(
    "/var/log/docker.log"
    "/var/log/ufw.log"
    "/var/log/audit/audit.log"
)

# Параметры анализа
ENABLE_PATTERN_ANALYSIS=true
ENABLE_ANOMALY_DETECTION=true
ENABLE_TREND_ANALYSIS=true
ENABLE_CORRELATION_ANALYSIS=true

# Временные окна для анализа (минуты)
TIME_WINDOWS=("5" "30" "60" "1440")

# Пороги для оповещений
ERROR_THRESHOLD=10
WARNING_THRESHOLD=5
SECURITY_THRESHOLD=3

# Настройки мониторинга в реальном времени
MONITOR_INTERVAL=2
FOLLOW_LOGS=true
COLORIZE_OUTPUT=true

# Настройки отчетов
REPORT_FORMAT="text"  # text, html, json
REPORT_RETENTION_DAYS=7
COMPRESS_OLD_REPORTS=true

# Настройки кэша
ENABLE_CACHING=true
CACHE_TTL=300  # секунды

# Настройки уведомлений
SEND_NOTIFICATIONS=false
NOTIFICATION_METHOD="console"  # console, email, telegram
EOF

    # Создание файла с шаблонами
    cat > "$PATTERNS_FILE" << 'EOF'
# Шаблоны для интеллектуального анализа логов

# Критические ошибки
CRITICAL_PATTERNS=(
    "error"
    "fail"
    "critical"
    "fatal"
    "panic"
    "oom"
    "out of memory"
    "segmentation fault"
    "kernel panic"
)

# Предупреждения
WARNING_PATTERNS=(
    "warning"
    "warn"
    "deprecated"
    "timeout"
    "slow"
    "retry"
)

# События безопасности
SECURITY_PATTERNS=(
    "failed password"
    "invalid user"
    "authentication failure"
    "brute force"
    "sql injection"
    "xss"
    "unauthorized"
    "access denied"
    "permission denied"
    "firewall"
    "iptables"
)

# Сетевые события
NETWORK_PATTERNS=(
    "connection refused"
    "connection timeout"
    "network unreachable"
    "port scan"
    "ddos"
    "flood"
)

# Системные события
SYSTEM_PATTERNS=(
    "reboot"
    "shutdown"
    "startup"
    "service started"
    "service stopped"
    "disk full"
    "cpu load"
)

# Приложения
APPLICATION_PATTERNS=(
    "nginx"
    "apache"
    "mysql"
    "postgresql"
    "docker"
    "kubernetes"
    "php"
    "python"
)
EOF

    print_success "Конфигурационные файлы созданы:"
    print_success "  $CONFIG_FILE"
    print_success "  $PATTERNS_FILE"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        # Значения по умолчанию
        LOG_FILES=(
            "/var/log/syslog"
            "/var/log/auth.log" 
            "/var/log/kern.log"
            "/var/log/dpkg.log"
        )
        ENABLE_PATTERN_ANALYSIS=true
        ENABLE_ANOMALY_DETECTION=true
        TIME_WINDOWS=("5" "30" "60")
        ERROR_THRESHOLD=10
        WARNING_THRESHOLD=5
    fi

    if [ -f "$PATTERNS_FILE" ]; then
        source "$PATTERNS_FILE"
    fi
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    local optional_missing=()
    
    # Обязательные утилиты
    for cmd in grep awk sed tail head wc; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные утилиты
    if ! command -v multitail &> /dev/null; then
        optional_missing+=("multitail")
    fi
    
    if ! command -v jq &> /dev/null; then
        optional_missing+=("jq")
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

# Проверка доступности логов
check_log_access() {
    local accessible_logs=()
    local total_logs=0
    
    print_section "ПРОВЕРКА ДОСТУПА К ЛОГАМ"
    
    # Основные логи
    for log_file in "${LOG_FILES[@]}"; do
        total_logs=$((total_logs + 1))
        if [ -r "$log_file" ]; then
            accessible_logs+=("$log_file")
            print_success "✅ Доступен: $log_file"
        elif [ -f "$log_file" ] && [ ! -r "$log_file" ]; then
            print_warning "⚠️  Нет прав на чтение: $log_file"
        else
            print_error "❌ Файл не найден: $log_file"
        fi
    done
    
    # Дополнительные логи
    if [ -n "${EXTRA_LOGS:-}" ]; then
        for log_file in "${EXTRA_LOGS[@]}"; do
            total_logs=$((total_logs + 1))
            if [ -r "$log_file" ]; then
                accessible_logs+=("$log_file")
                print_success "✅ Доступен (доп.): $log_file"
            fi
        done
    fi
    
    echo ""
    echo "📊 Итог: ${#accessible_logs[@]}/$total_logs логов доступно"
    
    if [ ${#accessible_logs[@]} -eq 0 ]; then
        print_error "❌ Нет доступных логов для анализа"
        echo ""
        echo "💡 Решения:"
        echo "  • Запустите скрипт с sudo: sudo $0"
        echo "  • Добавьте пользователя в группу adm: sudo usermod -aG adm \$USER"
        echo "  • Проверьте существование указанных логов"
        return 1
    fi
    
    return 0
}

# Кэширование результатов
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
    
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi
    
    # Очистка просроченных записей и поиск ключа
    while IFS='|' read -r cache_key value expire; do
        if [ "$current_time" -lt "$expire" ]; then
            if [ "$cache_key" = "$key" ]; then
                echo "$value"
                local found=1
            fi
            echo "$cache_key|$value|$expire" >> "$temp_file"
        fi
    done < "$CACHE_FILE"
    
    if [ -f "$temp_file" ]; then
        mv "$temp_file" "$CACHE_FILE"
    fi
    
    [ -n "${found:-}" ] && return 0 || return 1
}

# Умный поиск по шаблонам
pattern_search() {
    local log_file=$1
    local pattern_type=$2
    local time_window=${3:-}
    
    local cache_key="${log_file}_${pattern_type}_${time_window}"
    local cached_result
    
    if cached_result=$(cache_get "$cache_key"); then
        echo "$cached_result"
        return
    fi
    
    local patterns=()
    case $pattern_type in
        "critical")
            patterns=("${CRITICAL_PATTERNS[@]}")
            ;;
        "warning")  
            patterns=("${WARNING_PATTERNS[@]}")
            ;;
        "security")
            patterns=("${SECURITY_PATTERNS[@]}")
            ;;
        "network")
            patterns=("${NETWORK_PATTERNS[@]}")
            ;;
        *)
            patterns=("$pattern_type")
            ;;
    esac
    
    local grep_cmd="sudo grep -ahi"
    local time_filter=""
    
    if [ -n "$time_window" ]; then
        if command -v journalctl &> /dev/null && [[ "$log_file" == *"journal"* ]]; then
            time_filter="--since=\"$time_window minutes ago\""
        else
            time_filter="--since=\"$time_window minutes ago\""
        fi
    fi
    
    local total_count=0
    for pattern in "${patterns[@]}"; do
        local count
        if [ -n "$time_filter" ]; then
            count=$(eval "$grep_cmd $time_filter -c \"$pattern\" \"$log_file\" 2>/dev/null || echo \"0\"")
        else
            count=$(eval "$grep_cmd -c \"$pattern\" \"$log_file\" 2>/dev/null || echo \"0\"")
        fi
        total_count=$((total_count + count))
    done
    
    cache_set "$cache_key" "$total_count"
    echo "$total_count"
}

# Анализ аномалий
detect_anomalies() {
    local log_file=$1
    print_section "АНАЛИЗ АНОМАЛИЙ: $(basename "$log_file")"
    
    # Анализ частоты событий
    local recent_count=$(pattern_search "$log_file" "critical" 5)
    local historical_count=$(pattern_search "$log_file" "critical" 60)
    
    if [ "$historical_count" -gt 0 ]; then
        local ratio=$((recent_count * 100 / historical_count))
        if [ "$ratio" -gt 500 ]; then
            print_error "🚨 Всплеск ошибок: +$ratio% за последние 5 минут"
        elif [ "$ratio" -gt 200 ]; then
            print_warning "⚠️  Повышенная частота ошибок: +$ratio%"
        fi
    fi
    
    # Поиск необычных шаблонов
    local unusual_patterns=$(sudo grep -ahi -v -f <(printf "%s\n" "${CRITICAL_PATTERNS[@]}" "${WARNING_PATTERNS[@]}" "${SECURITY_PATTERNS[@]}") "$log_file" 2>/dev/null | \
        awk '{print $5}' | sort | uniq -c | sort -nr | head -5)
    
    if [ -n "$unusual_patterns" ]; then
        echo "  🔍 Необычные события:"
        echo "$unusual_patterns" | while read count pattern; do
            echo "    📊 $pattern: $count раз"
        done
    fi
}

# Расширенный анализ ошибок
analyze_errors() {
    print_section "РАСШИРЕННЫЙ АНАЛИЗ ОШИБОК"
    
    local total_critical=0
    local total_warnings=0
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            echo -e "\n${PURPLE}📋 $(basename "$log_file"):${NC}"
            
            local critical_count=0
            local warning_count=0
            
            # Анализ по временным окнам
            for window in "${TIME_WINDOWS[@]}"; do
                local window_critical=$(pattern_search "$log_file" "critical" "$window")
                local window_warning=$(pattern_search "$log_file" "warning" "$window")
                
                if [ "$window_critical" -gt 0 ] || [ "$window_warning" -gt 0 ]; then
                    echo "  ⏰ Последние $window минут:"
                    echo "    🚫 Критические: $window_critical"
                    echo "    ⚠️  Предупреждения: $window_warning"
                fi
                
                critical_count=$((critical_count + window_critical))
                warning_count=$((warning_count + window_warning))
            done
            
            total_critical=$((total_critical + critical_count))
            total_warnings=$((total_warnings + warning_count))
            
            # Детализация по типам ошибок
            if [ "$critical_count" -gt 0 ]; then
                echo "  🔍 Детализация критических ошибок:"
                for pattern in "${CRITICAL_PATTERNS[@]}"; do
                    local count=$(pattern_search "$log_file" "$pattern")
                    if [ "$count" -gt 0 ]; then
                        echo "    🎯 '$pattern': $count"
                    fi
                done
            fi
            
            # Анализ аномалий если включен
            if [ "$ENABLE_ANOMALY_DETECTION" = "true" ]; then
                detect_anomalies "$log_file"
            fi
        fi
    done
    
    echo ""
    echo "📈 ОБЩАЯ СТАТИСТИКА ОШИБОК:"
    echo "  🚫 Всего критических: $total_critical"
    echo "  ⚠️  Всего предупреждений: $total_warnings"
    
    if [ "$total_critical" -gt "$ERROR_THRESHOLD" ]; then
        print_error "❌ Превышен порог критических ошибок: $total_critical > $ERROR_THRESHOLD"
    fi
}

# Улучшенный анализ безопасности
analyze_security() {
    print_section "УГЛУБЛЕННЫЙ АНАЛИЗ БЕЗОПАСНОСТИ"
    
    if [ -r "/var/log/auth.log" ]; then
        local auth_log="/var/log/auth.log"
        
        # Расширенная статистика
        local failed_logins=$(pattern_search "$auth_log" "failed password" 60)
        local successful_logins=$(pattern_search "$auth_log" "accepted password" 60) 
        local invalid_users=$(pattern_search "$auth_log" "invalid user" 60)
        local sudo_commands=$(sudo grep -c "sudo:" "$auth_log" 2>/dev/null || echo "0")
        local session_opens=$(sudo grep -c "session opened" "$auth_log" 2>/dev/null || echo "0")
        
        echo "  🔐 Статистика за последний час:"
        echo "    🚫 Неудачных входов: $failed_logins"
        echo "    ✅ Успешных входов: $successful_logins"
        echo "    👤 Попыток невалидных пользователей: $invalid_users"
        echo "    ⚡ Команд sudo: $sudo_commands"
        echo "    🔓 Открытых сессий: $session_opens"
        
        # Анализ подозрительной активности
        if [ "$failed_logins" -gt "$SECURITY_THRESHOLD" ]; then
            print_error "🚨 Возможная атака brute force: $failed_logins неудачных попыток"
            
            # Поиск подозрительных IP
            echo "  🔍 Подозрительные IP:"
            sudo grep "Failed password" "$auth_log" 2>/dev/null | \
                awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -5 | \
                while read count ip; do
                    echo "    🕵️  $ip: $count попыток"
                done
        fi
        
        # Анализ временных паттернов
        echo "  📊 Временное распределение:"
        for window in "5" "15" "30"; do
            local window_failed=$(pattern_search "$auth_log" "failed password" "$window")
            echo "    ⏱️  Последние $window минут: $window_failed неудачных попыток"
        done
        
    else
        print_warning "⚠️  Лог аутентификации недоступен"
    fi
    
    # Проверка других логов безопасности
    if [ -r "/var/log/ufw.log" ]; then
        local blocked_connections=$(sudo grep -c "BLOCK" "/var/log/ufw.log" 2>/dev/null || echo "0")
        echo "  🔥 UFW заблокировал соединений: $blocked_connections"
    fi
}

# Генерация статистики
generate_stats() {
    print_section "ДЕТАЛЬНАЯ СТАТИСТИКА ЛОГОВ"
    
    local total_size=0
    local total_lines=0
    local processed_files=0
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            local size=$(sudo du -b "$log_file" 2>/dev/null | cut -f1 || echo "0")
            local lines=$(sudo wc -l "$log_file" 2>/dev/null | awk '{print $1}' || echo "0")
            local modified=$(sudo stat -c %y "$log_file" 2>/dev/null | cut -d' ' -f1 || echo "неизвестно")
            local rate=""
            
            total_size=$((total_size + size))
            total_lines=$((total_lines + lines))
            processed_files=$((processed_files + 1))
            
            # Расчет скорости записи (если доступна история)
            if [ -f "$CACHE_FILE" ]; then
                local last_size=$(cache_get "${log_file}_size" || echo "0")
                if [ "$last_size" -gt 0 ] && [ "$size" -gt "$last_size" ]; then
                    local growth=$((size - last_size))
                    local growth_rate=$((growth / 3600))  # байт в час
                    rate=" ($(numfmt --to=iec $growth_rate)/час)"
                fi
                cache_set "${log_file}_size" "$size" 3600
            fi
            
            echo "  📊 $(basename "$log_file"):"
            echo "    📏 Размер: $(numfmt --to=iec $size)$rate"
            echo "    📄 Строк: $lines"
            echo "    📅 Изменен: $modified"
            
            # Анализ скорости роста
            if [ "$lines" -gt 1000 ]; then
                local today_lines=$(sudo grep -c "$(date +%Y-%m-%d)" "$log_file" 2>/dev/null || echo "0")
                if [ "$today_lines" -gt 0 ]; then
                    echo "    🚀 За сегодня: $today_lines записей"
                fi
            fi
        fi
    done
    
    echo ""
    echo "📈 ОБЩАЯ СТАТИСТИКА:"
    echo "    💾 Всего данных: $(numfmt --to=iec $total_size)"
    echo "    📖 Всего строк: $total_lines"
    echo "    📂 Обработано файлов: $processed_files"
    echo "    🗂️  Средний размер: $(numfmt --to=iec $((total_size / (processed_files > 0 ? processed_files : 1))))"
    
    # Предупреждение о больших логах
    if [ "$total_size" -gt 104857600 ]; then  # 100MB
        print_warning "⚠️  Суммарный размер логов превышает 100MB"
    fi
}

# Улучшенный мониторинг в реальном времени
real_time_monitor() {
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        exit 1
    fi
    
    print_section "УЛУЧШЕННЫЙ МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "  Нажмите Ctrl+C для остановки"
    echo "  Отслеживаемые файлы:"
    
    local monitor_files=()
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            echo "    👁️  $(basename "$log_file")"
            monitor_files+=("$log_file")
        fi
    done
    
    echo ""
    echo "  ⚙️  Настройки:"
    echo "    🎨 Цветной вывод: $COLORIZE_OUTPUT"
    echo "    🔄 Интервал: $MONITOR_INTERVAL сек"
    echo "    📍 Режим: $([ "$FOLLOW_LOGS" = "true" ] && echo "слежение" || echo "опрос")"
    echo ""
    
    # Используем multitail если доступен
    if command -v multitail >/dev/null 2>&1 && [ "$COLORIZE_OUTPUT" = "true" ]; then
        echo "  🚀 Используем multitail для продвинутого мониторинга..."
        local multitail_cmd="multitail"
        
        for file in "${monitor_files[@]}"; do
            multitail_cmd="$multitail_cmd \"$file\""
        done
        
        eval sudo $multitail_cmd
        
    else
        echo "  ℹ️  Используем умный polling-режим..."
        echo "  💡 Для лучшего опыта установите: sudo apt install multitail"
        echo ""
        
        local counter=0
        while true; do
            counter=$((counter + 1))
            echo "======= Сканирование #$counter ($(date '+%H:%M:%S')) ======="
            
            local has_updates=0
            for log_file in "${monitor_files[@]}"; do
                local current_size=$(sudo stat -c %s "$log_file" 2>/dev/null || echo "0")
                local last_size=$(cache_get "${log_file}_monitor" || echo "0")
                
                if [ "$current_size" -ne "$last_size" ]; then
                    has_updates=1
                    echo -e "\n${PURPLE}🆕 Новые записи в $(basename "$log_file"):${NC}"
                    
                    # Показываем только новые записи
                    if [ "$last_size" -gt 0 ]; then
                        sudo tail -c +$((last_size + 1)) "$log_file" 2>/dev/null | while read line; do
                            # Цветное форматирование
                            if echo "$line" | grep -q -i "error\|fail\|critical"; then
                                echo -e "${RED}🚨 $line${NC}"
                            elif echo "$line" | grep -q -i "warning"; then
                                echo -e "${YELLOW}⚠️  $line${NC}"
                            elif echo "$line" | grep -q -i "accepted\|success"; then
                                echo -e "${GREEN}✅ $line${NC}"
                            elif echo "$line" | grep -q -i "failed\|denied"; then
                                echo -e "${ORANGE}❌ $line${NC}"
                            else
                                echo "  📝 $line"
                            fi
                        done
                    fi
                    
                    cache_set "${log_file}_monitor" "$current_size"
                fi
            done
            
            if [ "$has_updates" -eq 0 ]; then
                echo "  🔄 Изменений нет..."
            fi
            
            sleep "$MONITOR_INTERVAL"
            echo "======================================"
        done
    fi
}

# Генерация отчета
generate_report() {
    local report_file="$REPORT_DIR/log-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_header > "$report_file"
    echo "📅 Отчет создан: $(date)" >> "$report_file"
    echo "💻 Система: $(uname -a)" >> "$report_file"
    echo "👤 Пользователь: $(whoami)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Сбор данных
    analyze_errors >> "$report_file" 2>&1
    echo "" >> "$report_file"
    analyze_security >> "$report_file" 2>&1
    echo "" >> "$report_file"
    generate_stats >> "$report_file" 2>&1
    
    print_success "Отчет сохранен: $report_file"
    echo "  📊 Сводка:"
    tail -20 "$report_file" | grep -E "🚨|⚠️|✅|📈" || echo "    ℹ️  Подробности в файле отчета"
}

# Очистка старых отчетов
clean_reports() {
    print_section "ОЧИСТКА СТАРЫХ ОТЧЕТОВ"
    
    local retention_days=${REPORT_RETENTION_DAYS:-7}
    local cutoff_date=$(date -d "$retention_days days ago" +%Y%m%d)
    local deleted_count=0
    
    for report in "$REPORT_DIR"/log-report-*.txt; do
        if [ -f "$report" ]; then
            local report_date=$(echo "$report" | grep -oE '[0-9]{8}' | head -1)
            if [ "$report_date" -lt "$cutoff_date" ]; then
                rm "$report"
                deleted_count=$((deleted_count + 1))
                echo "  🗑️  Удален: $(basename "$report")"
            fi
        fi
    done
    
    if [ "$deleted_count" -eq 0 ]; then
        print_success "Нет отчетов для удаления"
    else
        print_success "Удалено отчетов: $deleted_count"
    fi
}

# Поиск по шаблону
pattern_search_command() {
    local pattern=$1
    local time_window=${2:-}
    
    print_section "ПОИСК ПО ШАБЛОНУ: '$pattern'"
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -r "$log_file" ]; then
            local count=$(pattern_search "$log_file" "$pattern" "$time_window")
            if [ "$count" -gt 0 ]; then
                echo "  📁 $(basename "$log_file"): $count совпадений"
                
                # Показать примеры
                local examples
                if [ -n "$time_window" ]; then
                    examples=$(sudo grep -ahi --since="$time_window minutes ago" "$pattern" "$log_file" 2>/dev/null | head -3)
                else
                    examples=$(sudo grep -ahi "$pattern" "$log_file" 2>/dev/null | head -3)
                fi
                
                if [ -n "$examples" ]; then
                    echo "    📍 Примеры:"
                    echo "$examples" | while read example; do
                        echo "      • $(echo "$example" | cut -c1-100)..."
                    done
                fi
            fi
        fi
    done
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "errors")
            print_header
            analyze_errors
            ;;
        "security")
            print_header
            analyze_security
            ;;
        "stats")
            print_header
            generate_stats
            ;;
        "monitor")
            print_header
            real_time_monitor
            ;;
        "report")
            print_header
            generate_report
            ;;
        "clean")
            clean_reports
            ;;
        "config")
            create_config
            ;;
        "search")
            print_header
            pattern_search_command "${2:-}" "${3:-}"
            ;;
        "test")
            print_header
            check_dependencies
            check_log_access
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  errors           - Расширенный анализ ошибок"
            echo "  security         - Углубленный анализ безопасности"
            echo "  stats            - Детальная статистика логов"
            echo "  monitor          - Мониторинг в реальном времени"
            echo "  report           - Полный отчет"
            echo "  clean            - Очистка старых отчетов"
            echo "  config           - Создать конфигурационные файлы"
            echo "  search PATTERN   - Поиск по шаблону"
            echo "  test             - Тестирование системы"
            echo "  help             - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 errors"
            echo "  $0 security"
            echo "  $0 monitor"
            echo "  $0 search 'error' 30    # Поиск ошибок за 30 минут"
            echo "  $0 report"
            echo ""
            echo "💡 Для полного доступа к логам используйте sudo"
            ;;
        *)
            print_error "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            exit 1
            ;;
    esac
}

# Инициализация
if [ "$#" -eq 0 ]; then
    print_header
    check_log_access || exit 1
fi

main "$@"
