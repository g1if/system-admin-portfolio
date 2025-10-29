#!/bin/bash
# 🧪 Комплексная система тестирования всех скриптов портфолио
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports"
TESTS_DIR="$PROJECT_ROOT/tests"
LOG_FILE="$LOG_DIR/script-tests.log"
REPORT_FILE="$REPORTS_DIR/test-report-$(date +%Y%m%d_%H%M%S).html"

mkdir -p "$LOG_DIR" "$REPORTS_DIR" "$TESTS_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Логирование
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING" "$1"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
    log "INFO" "$1"
}

print_header() {
    echo -e "${MAGENTA}"
    echo "🧪 ==========================================="
    echo "   КОМПЛЕКСНАЯ СИСТЕМА ТЕСТИРОВАНИЯ v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

# Статистика тестирования
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Функция для тестирования скрипта
test_script() {
    local script_name=$1
    local test_type=$2
    local test_command=$3
    local description=$4
    
    ((TOTAL_TESTS++))
    
    echo -n "🔍 Тестируем $script_name ($test_type)... "
    
    if [ ! -f "./scripts/$script_name" ]; then
        echo -e "${RED}📛 NOT FOUND${NC}"
        log "ERROR" "Скрипт $script_name не найден"
        ((FAILED_TESTS++))
        return 2
    fi
    
    # Проверяем права доступа
    if [ ! -x "./scripts/$script_name" ]; then
        chmod +x "./scripts/$script_name"
        print_warning "Исправлены права доступа для $script_name"
    fi
    
    # Выполняем тест
    if eval $test_command >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        log "SUCCESS" "$script_name ($test_type): $description - PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        log "ERROR" "$script_name ($test_type): $description - FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Проверка синтаксиса Bash
test_syntax() {
    local script_name=$1
    
    echo -n "🔧 Проверка синтаксиса $script_name... "
    
    if bash -n "./scripts/$script_name" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ VALID${NC}"
        log "SUCCESS" "Синтаксис $script_name корректен"
        return 0
    else
        echo -e "${RED}❌ INVALID${NC}"
        log "ERROR" "Ошибка синтаксиса в $script_name"
        return 1
    fi
}

# Проверка с shellcheck
test_shellcheck() {
    local script_name=$1
    
    if ! command -v shellcheck &> /dev/null; then
        return 0  # shellcheck не установлен, пропускаем
    fi
    
    echo -n "📋 ShellCheck $script_name... "
    
    if shellcheck "./scripts/$script_name" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ CLEAN${NC}"
        log "SUCCESS" "ShellCheck $script_name прошел без ошибок"
        return 0
    else
        echo -e "${YELLOW}⚠️  WARNINGS${NC}"
        log "WARNING" "ShellCheck обнаружил предупреждения в $script_name"
        return 0  # Предупреждения не считаем за ошибку
    fi
}

# Комплексное тестирование скрипта
comprehensive_test() {
    local script_name=$1
    local test_command=$2
    local description=$3
    
    print_info "Комплексное тестирование: $script_name"
    
    # Тест синтаксиса
    test_syntax "$script_name"
    
    # Тест shellcheck
    test_shellcheck "$script_name"
    
    # Основной тест
    test_script "$script_name" "functionality" "$test_command" "$description"
    
    echo ""
}

# Тестирование системного монитора
test_system_monitor() {
    comprehensive_test "system-monitor.sh" \
        "./scripts/system-monitor.sh --help" \
        "Проверка работы системного монитора"
    
    # Дополнительные тесты для system-monitor
    test_script "system-monitor.sh" "quick" \
        "./scripts/system-monitor.sh quick" \
        "Быстрая проверка системы"
    
    test_script "system-monitor.sh" "config" \
        "./scripts/system-monitor.sh config" \
        "Генерация конфигурации"
}

# Тестирование менеджера сервисов
test_service_manager() {
    comprehensive_test "service-manager.sh" \
        "./scripts/service-manager.sh --help" \
        "Проверка менеджера сервисов"
    
    test_script "service-manager.sh" "list" \
        "./scripts/service-manager.sh list" \
        "Список сервисов"
    
    test_script "service-manager.sh" "status" \
        "./scripts/service-manager.sh status" \
        "Статус сервисов"
}

# Тестирование менеджера пользователей
test_user_manager() {
    comprehensive_test "user-manager.sh" \
        "./scripts/user-manager.sh --help" \
        "Проверка менеджера пользователей"
    
    test_script "user-manager.sh" "list-users" \
        "./scripts/user-manager.sh list-users" \
        "Список пользователей"
    
    test_script "user-manager.sh" "list-groups" \
        "./scripts/user-manager.sh list-groups" \
        "Список групп"
}

# Тестирование системы оповещений
test_alert_system() {
    comprehensive_test "alert-system.sh" \
        "./scripts/alert-system.sh --help" \
        "Проверка системы оповещений"
    
    test_script "alert-system.sh" "config" \
        "./scripts/alert-system.sh config" \
        "Генерация конфигурации"
    
    test_script "alert-system.sh" "test" \
        "./scripts/alert-system.sh test" \
        "Тестирование оповещений"
}

# Тестирование резервного копирования
test_backup_manager() {
    comprehensive_test "backup-manager.sh" \
        "./scripts/backup-manager.sh --help" \
        "Проверка менеджера резервных копий"
    
    test_script "backup-manager.sh" "config" \
        "./scripts/backup-manager.sh config" \
        "Генерация конфигурации"
}

# Тестирование безопасности
test_security_audit() {
    comprehensive_test "security-audit.sh" \
        "./scripts/security-audit.sh --help" \
        "Проверка системы безопасности"
    
    test_script "security-audit.sh" "quick" \
        "./scripts/security-audit.sh quick" \
        "Быстрая проверка безопасности"
}

# Тестирование сети
test_network_tools() {
    comprehensive_test "network-analyzer.sh" \
        "./scripts/network-analyzer.sh --help" \
        "Проверка анализатора сети"
    
    comprehensive_test "ssl-cert-checker.sh" \
        "./scripts/ssl-cert-checker.sh --help" \
        "Проверка мониторинга SSL"
    
    test_script "ssl-cert-checker.sh" "config" \
        "./scripts/ssl-cert-checker.sh config" \
        "Генерация конфигурации SSL"
}

# Тестирование дисков
test_disk_tools() {
    comprehensive_test "disk-manager.sh" \
        "./scripts/disk-manager.sh --help" \
        "Проверка менеджера дисков"
    
    test_script "disk-manager.sh" "info" \
        "./scripts/disk-manager.sh info" \
        "Информация о дисках"
}

# Тестирование Docker
test_docker_tools() {
    comprehensive_test "docker-manager.sh" \
        "./scripts/docker-manager.sh --help" \
        "Проверка менеджера Docker"
    
    comprehensive_test "install-docker.sh" \
        "./scripts/install-docker.sh --help" \
        "Проверка установщика Docker"
}

# Тестирование утилит
test_utility_tools() {
    comprehensive_test "package-manager.sh" \
        "./scripts/package-manager.sh help" \
        "Проверка менеджера пакетов"
    
    comprehensive_test "cron-manager.sh" \
        "./scripts/cron-manager.sh --help" \
        "Проверка менеджера cron"
    
    comprehensive_test "process-monitor.sh" \
        "./scripts/process-monitor.sh --help" \
        "Проверка монитора процессов"
    
    comprehensive_test "log-analyzer.sh" \
        "./scripts/log-analyzer.sh --help" \
        "Проверка анализатора логов"
    
    comprehensive_test "firewall-manager.sh" \
        "./scripts/firewall-manager.sh --help" \
        "Проверка менеджера фаервола"
    
    comprehensive_test "metrics-collector.sh" \
        "./scripts/metrics-collector.sh --help" \
        "Проверка сборщика метрик"
}

# Тестирование Git помощника
test_git_helper() {
    comprehensive_test "git-helper.sh" \
        "./scripts/git-helper.sh --help" \
        "Проверка Git помощника"
    
    test_script "git-helper.sh" "status" \
        "./scripts/git-helper.sh status" \
        "Статус Git репозитория"
    
    test_script "git-helper.sh" "info" \
        "./scripts/git-helper.sh info" \
        "Информация о репозитории"
}

# Тестирование установщика
test_installer() {
    if [ -f "./bootstrap.sh" ]; then
        comprehensive_test "bootstrap.sh" \
            "./bootstrap.sh --help" \
            "Проверка системного установщика"
        
        test_syntax "bootstrap.sh"
        test_shellcheck "bootstrap.sh"
    fi
}

# Проверка прав доступа
test_permissions() {
    print_info "Проверка прав доступа скриптов..."
    
    local invalid_permissions=0
    
    for script in ./scripts/*.sh; do
        if [ -f "$script" ]; then
            if [ ! -x "$script" ]; then
                print_error "❌ $(basename "$script"): не исполняемый"
                chmod +x "$script"
                print_warning "  🔧 Исправлены права доступа"
                ((invalid_permissions++))
            fi
        fi
    done
    
    if [ $invalid_permissions -eq 0 ]; then
        print_success "✅ Все скрипты имеют правильные права доступа"
    else
        print_warning "⚠️  Исправлены права доступа для $invalid_permissions скриптов"
    fi
}

# Проверка зависимостей
test_dependencies() {
    print_info "Проверка системных зависимостей..."
    
    local dependencies=(
        "bash" "awk" "grep" "sed" "cut" "sort" "uniq"
        "curl" "wget" "git" "sudo" "systemctl" "journalctl"
        "ps" "top" "free" "df" "du" "find" "tar" "gzip"
        "ping" "ip" "ss" "netstat" "lsof" "uptime" "who"
    )
    
    local missing_deps=0
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo -e "  ${GREEN}✅ $dep${NC}"
        else
            echo -e "  ${RED}❌ $dep${NC}"
            ((missing_deps++))
        fi
    done
    
    if [ $missing_deps -eq 0 ]; then
        print_success "✅ Все основные зависимости установлены"
    else
        print_warning "⚠️  Отсутствуют $missing_deps зависимостей"
    fi
}

# Проверка опциональных утилит
test_optional_dependencies() {
    print_info "Проверка опциональных утилит..."
    
    local optional_deps=(
        "shellcheck" "smartctl" "iotop" "htop" "ncdu" "tree"
        "nmap" "sensors" "docker" "docker-compose" "jq" "bc"
        "rsync" "rclone" "fail2ban-server" "ufw" "clamscan"
    )
    
    local available_deps=0
    
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo -e "  ${GREEN}✅ $dep${NC}"
            ((available_deps++))
        else
            echo -e "  ${YELLOW}⚠️  $dep${NC}"
        fi
    done
    
    print_info "Доступно $available_deps из ${#optional_deps[@]} опциональных утилит"
}

# Проверка конфигурационных файлов
test_configs() {
    print_info "Проверка конфигурационных файлов..."
    
    local config_files=(
        "configs/system-monitor.conf"
        "configs/alert.conf" 
        "configs/backup.conf"
        "configs/ssl-domains.conf"
        "configs/service-manager.conf"
        "configs/user-manager.conf"
    )
    
    local missing_configs=0
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            echo -e "  ${GREEN}✅ $(basename "$config")${NC}"
        else
            echo -e "  ${YELLOW}⚠️  $(basename "$config")${NC}"
            ((missing_configs++))
        fi
    done
    
    if [ $missing_configs -eq 0 ]; then
        print_success "✅ Все конфигурационные файлы присутствуют"
    else
        print_warning "⚠️  Отсутствуют $missing_configs конфигурационных файлов"
        print_info "💡 Запустите скрипты с командой 'config' для их создания"
    fi
}

# Генерация отчета
generate_report() {
    print_info "Генерация детального отчета..."
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Отчет тестирования - System Admin Portfolio</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .test-result { margin: 10px 0; padding: 10px; border-left: 4px solid; }
        .passed { border-color: #28a745; background: #f8fff9; }
        .failed { border-color: #dc3545; background: #fff8f8; }
        .skipped { border-color: #ffc107; background: #fffef0; }
        .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 20px 0; }
        .stat-card { padding: 15px; text-align: center; border-radius: 5px; color: white; }
        .total { background: #17a2b8; }
        .passed-stat { background: #28a745; }
        .failed-stat { background: #dc3545; }
        .success-rate { background: #6f42c1; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Отчет тестирования системы</h1>
        <p><strong>Проект:</strong> System Admin Portfolio</p>
        <p><strong>Дата:</strong> $(date)</p>
        <p><strong>Версия:</strong> 2.0</p>
    </div>
    
    <div class="stats">
        <div class="stat-card total">
            <h3>Всего тестов</h3>
            <p style="font-size: 24px; margin: 0;">$TOTAL_TESTS</p>
        </div>
        <div class="stat-card passed-stat">
            <h3>Пройдено</h3>
            <p style="font-size: 24px; margin: 0;">$PASSED_TESTS</p>
        </div>
        <div class="stat-card failed-stat">
            <h3>Не пройдено</h3>
            <p style="font-size: 24px; margin: 0;">$FAILED_TESTS</p>
        </div>
        <div class="stat-card success-rate">
            <h3>Успешность</h3>
            <p style="font-size: 24px; margin: 0;">${success_rate}%</p>
        </div>
    </div>
    
    <div class="summary">
        <h2>Резюме</h2>
        <p>Система тестирования проверила все основные компоненты портфолио администратора.</p>
        <p><strong>Лог тестирования:</strong> $LOG_FILE</p>
    </div>
    
    <div>
        <h2>Рекомендации</h2>
        <ul>
EOF

    if [ $FAILED_TESTS -gt 0 ]; then
        echo "<li>❌ Проверьте ошибки в логе тестирования</li>" >> "$REPORT_FILE"
    fi
    
    if [ $success_rate -lt 80 ]; then
        echo "<li>⚠️  Рекомендуется улучшить покрытие тестами</li>" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF
            <li>✅ Регулярно запускайте тестирование после изменений</li>
            <li>📚 Изучите логи для детальной диагностики проблем</li>
        </ul>
    </div>
</body>
</html>
EOF

    print_success "Отчет сгенерирован: $REPORT_FILE"
}

# Основная функция тестирования
main() {
    print_header
    
    echo "Начало комплексного тестирования системы..."
    echo "Логи: $LOG_FILE"
    echo ""
    
    # Сбрасываем статистику
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    SKIPPED_TESTS=0
    
    # Выполняем тесты
    test_permissions
    echo ""
    
    test_dependencies
    echo ""
    
    test_optional_dependencies
    echo ""
    
    test_configs
    echo ""
    
    print_info "Тестирование основных скриптов..."
    echo "======================================"
    
    test_system_monitor
    test_service_manager
    test_user_manager
    test_alert_system
    test_backup_manager
    test_security_audit
    test_network_tools
    test_disk_tools
    test_docker_tools
    test_utility_tools
    test_git_helper
    test_installer
    
    # Итоги
    echo ""
    echo "🧪 ИТОГИ ТЕСТИРОВАНИЯ:"
    echo "====================="
    echo -e "📊 Всего тестов: $TOTAL_TESTS"
    echo -e "${GREEN}✅ Пройдено: $PASSED_TESTS${NC}"
    echo -e "${RED}❌ Не пройдено: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}⚠️  Пропущено: $SKIPPED_TESTS${NC}"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    echo -e "📈 Успешность: ${success_rate}%"
    
    echo ""
    echo "📝 Подробный лог: $LOG_FILE"
    
    # Генерация отчета
    generate_report
    
    echo ""
    echo "📋 HTML отчет: $REPORT_FILE"
    
    # Возвращаем код выхода
    if [ $FAILED_TESTS -gt 0 ]; then
        print_error "Тестирование завершено с ошибками"
        exit 1
    else
        print_success "Все тесты пройдены успешно!"
        exit 0
    fi
}

# Быстрое тестирование
quick_test() {
    print_header
    echo "⚡ Быстрое тестирование основных скриптов..."
    echo ""
    
    test_system_monitor
    test_service_manager
    test_user_manager
    test_alert_system
    test_git_helper
    
    echo ""
    echo "🧪 Быстрое тестирование завершено"
    echo -e "${GREEN}✅ Пройдено: $PASSED_TESTS${NC}"
    echo -e "${RED}❌ Не пройдено: $FAILED_TESTS${NC}"
}

# Проверка синтаксиса
syntax_check() {
    print_header
    echo "🔍 Проверка синтаксиса всех скриптов..."
    echo ""
    
    local syntax_errors=0
    
    for script in ./scripts/*.sh; do
        if [ -f "$script" ]; then
            if ! test_syntax "$(basename "$script")"; then
                ((syntax_errors++))
            fi
        fi
    done
    
    if [ -f "./bootstrap.sh" ]; then
        if ! test_syntax "bootstrap.sh"; then
            ((syntax_errors++))
        fi
    fi
    
    echo ""
    if [ $syntax_errors -eq 0 ]; then
        print_success "✅ Синтаксис всех скриптов корректен"
    else
        print_error "❌ Найдено $syntax_errors ошибок синтаксиса"
        exit 1
    fi
}

# Показать справку
show_help() {
    print_header
    echo -e "${CYAN}Использование: $0 [КОМАНДА]${NC}"
    echo ""
    echo "Команды:"
    echo "  full       - Полное тестирование (по умолчанию)"
    echo "  quick      - Быстрое тестирование основных скриптов"
    echo "  syntax     - Проверка синтаксиса"
    echo "  deps       - Проверка зависимостей"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0          # Полное тестирование"
    echo "  $0 quick    # Быстрое тестирование"
    echo "  $0 syntax   # Только проверка синтаксиса"
    echo ""
    echo "Файлы:"
    echo "  Логи: $LOG_DIR/script-tests.log"
    echo "  Отчеты: $REPORTS_DIR/test-report-*.html"
}

# Обработка аргументов
case "${1:-full}" in
    "full")
        main
        ;;
    "quick")
        quick_test
        ;;
    "syntax")
        syntax_check
        ;;
    "deps")
        test_dependencies
        test_optional_dependencies
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
