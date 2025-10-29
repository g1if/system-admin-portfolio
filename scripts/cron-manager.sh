#!/bin/bash
# ⏰ Менеджер cron заданий с расширенными функциями
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
BACKUP_DIR="$PROJECT_ROOT/backups"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Файлы
CRON_BACKUP="$BACKUP_DIR/cron-backup-$(date +%Y%m%d_%H%M%S).txt"
LOG_FILE="$LOG_DIR/cron-manager.log"

# Логирование
log() {
    local level=${2:-"INFO"}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "⏰ ==========================================="
    echo "   МЕНЕДЖЕР CRON ЗАДАНИЙ v2.0"
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
    log "$1" "SUCCESS"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "$1" "ERROR"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "$1" "WARNING"
}

print_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
    log "$1" "INFO"
}

# Проверка зависимостей
check_dependencies() {
    if ! command -v crontab &> /dev/null; then
        print_error "Утилита 'crontab' не найдена"
        echo "💡 Установите: sudo apt install cron"
        return 1
    fi
    
    if ! systemctl is-active cron >/dev/null 2>&1 && ! systemctl is-active crond >/dev/null 2>&1; then
        print_warning "Служба cron не запущена"
        echo "💡 Запустите: sudo systemctl start cron"
    fi
    
    return 0
}

# Проверка синтаксиса cron выражения
validate_cron_expression() {
    local expression="$1"
    local cmd="$2"
    
    # Базовая проверка формата
    if [[ ! "$expression" =~ ^([0-9*,-/]+[[:space:]]+){4}[0-9*,-/]+$ ]]; then
        print_error "Неверный формат cron выражения: $expression"
        echo "💡 Формат: * * * * * (минута час день месяц день_недели)"
        return 1
    fi
    
    # Проверка что команда не пустая
    if [ -z "$cmd" ]; then
        print_error "Команда не может быть пустой"
        return 1
    fi
    
    # Проверка доступности команды (если это исполняемый файл)
    local first_word=$(echo "$cmd" | awk '{print $1}')
    if [[ "$first_word" != "echo" ]] && [[ "$first_word" != "cd" ]] && \
       [[ "$first_word" != "source" ]] && [[ "$first_word" != "." ]] && \
       command -v "$first_word" >/dev/null 2>&1; then
        if ! command -v "$first_word" &> /dev/null; then
            print_warning "Команда '$first_word' не найдена в системе"
        fi
    fi
    
    return 0
}

# Создание бэкапа текущих заданий
backup_cron() {
    local backup_file="$CRON_BACKUP"
    
    print_section "СОЗДАНИЕ БЭКАПА CRON"
    
    if crontab -l > "$backup_file" 2>/dev/null; then
        local size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
        print_success "Бэкап создан: $(basename "$backup_file")"
        echo "  📁 Файл: $backup_file"
        echo "  📊 Размер: ${size} байт"
        log "Создан бэкап cron: $backup_file" "INFO"
    else
        print_warning "Нет заданий для бэкапа"
    fi
}

# Список заданий с детальной информацией
list_jobs() {
    print_section "ТЕКУЩИЕ CRON ЗАДАНИЯ"
    
    # Задания текущего пользователя
    echo "👤 ЗАДАНИЯ ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ ($USER):"
    echo ""
    
    local user_jobs=$(crontab -l 2>/dev/null)
    if [ -n "$user_jobs" ]; then
        local counter=0
        while IFS= read -r line; do
            # Пропускаем пустые строки и комментарии
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                counter=$((counter + 1))
                echo "  $counter. $line"
                
                # Парсим cron выражение для пояснения
                if [[ "$line" =~ ^([0-9*,-/]+[[:space:]]+){4}[0-9*,-/]+[[:space:]]+(.*)$ ]]; then
                    local cron_expr="${BASH_REMATCH[1]}"
                    local command="${BASH_REMATCH[2]}"
                    explain_cron_expression "$cron_expr"
                fi
                echo ""
            elif [[ "$line" =~ ^#.*$ && -n "$line" ]]; then
                # Показываем закомментированные задания
                echo "  💤 [ЗАКОММЕНТИРОВАНО] ${line:1}"
                echo ""
            fi
        done <<< "$user_jobs"
        
        if [ $counter -eq 0 ]; then
            echo "  ℹ️  Нет активных заданий"
        fi
    else
        echo "  ℹ️  Нет заданий"
    fi
    
    # Системные задания
    echo ""
    echo "📁 СИСТЕМНЫЕ ЗАДАНИЯ:"
    echo ""
    
    local system_jobs_found=0
    
    # Проверяем различные системные cron директории
    local cron_dirs=("/etc/cron.d" "/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly")
    
    for cron_dir in "${cron_dirs[@]}"; do
        if [ -d "$cron_dir" ]; then
            local files=($(ls "$cron_dir" 2>/dev/null))
            if [ ${#files[@]} -gt 0 ]; then
                system_jobs_found=1
                echo "  📂 $cron_dir:"
                for file in "${files[@]}"; do
                    if [ -f "$cron_dir/$file" ] && [ "$file" != ".placeholder" ]; then
                        echo "    📄 $file"
                    fi
                done
                echo ""
            fi
        fi
    done
    
    if [ $system_jobs_found -eq 0 ]; then
        echo "  ℹ️  Системные задания не найдены"
    fi
}

# Пояснение cron выражения
explain_cron_expression() {
    local expression="$1"
    local parts=($expression)
    
    if [ ${#parts[@]} -ne 5 ]; then
        return
    fi
    
    local minute="${parts[0]}"
    local hour="${parts[1]}"
    local day="${parts[2]}"
    local month="${parts[3]}"
    local weekday="${parts[4]}"
    
    echo -e "    📅 Расписание:"
    
    # Минуты
    if [ "$minute" == "*" ]; then
        echo "      🕐 Минуты: каждую минуту"
    else
        echo "      🕐 Минуты: $minute"
    fi
    
    # Часы
    if [ "$hour" == "*" ]; then
        echo "      🕑 Часы: каждый час"
    else
        echo "      🕑 Часы: $hour"
    fi
    
    # Дни месяца
    if [ "$day" == "*" ]; then
        echo "      📅 Дни месяца: каждый день"
    else
        echo "      📅 Дни месяца: $day"
    fi
    
    # Месяцы
    if [ "$month" == "*" ]; then
        echo "      🌸 Месяцы: каждый месяц"
    else
        local months=("" "Январь" "Февраль" "Март" "Апрель" "Май" "Июнь" 
                     "Июль" "Август" "Сентябрь" "Октябрь" "Ноябрь" "Декабрь")
        echo "      🌸 Месяцы: $month (${months[$month]})"
    fi
    
    # Дни недели
    if [ "$weekday" == "*" ]; then
        echo "      📆 Дни недели: каждый день"
    else
        local days=("Воскресенье" "Понедельник" "Вторник" "Среда" "Четверг" "Пятница" "Суббота")
        echo "      📆 Дни недели: $weekday (${days[$weekday]})"
    fi
}

# Добавление задания
add_job() {
    print_section "ДОБАВЛЕНИЕ НОВОГО ЗАДАНИЯ"
    
    echo "📝 Формат: * * * * * команда"
    echo "   минута час день месяц день_недели"
    echo ""
    echo "💡 Примеры:"
    echo "   0 2 * * * /path/to/backup.sh    # Ежедневно в 2:00"
    echo "   */5 * * * * /path/to/check.sh   # Каждые 5 минут"
    echo "   0 0 1 * * /path/to/report.sh    # Первого числа каждого месяца"
    echo ""
    
    read -p "Введите cron выражение: " cron_expr
    read -p "Введите команду: " command
    
    # Валидация
    if ! validate_cron_expression "$cron_expr" "$command"; then
        return 1
    fi
    
    # Создаем бэкап перед изменением
    backup_cron
    
    # Добавляем задание
    local current_jobs=$(crontab -l 2>/dev/null || true)
    local new_jobs=$(printf "%s\n%s %s" "$current_jobs" "$cron_expr" "$command")
    
    if echo "$new_jobs" | crontab -; then
        print_success "Задание добавлено"
        echo "  📋 Выражение: $cron_expr"
        echo "  💻 Команда: $command"
        log "Добавлено cron задание: $cron_expr $command" "INFO"
    else
        print_error "Ошибка добавления задания"
        return 1
    fi
}

# Удаление задания
remove_job() {
    print_section "УДАЛЕНИЕ ЗАДАНИЯ"
    
    local current_jobs=$(crontab -l 2>/dev/null)
    
    if [ -z "$current_jobs" ]; then
        echo "  ℹ️  Нет заданий для удаления"
        return 0
    fi
    
    echo "📋 Текущие задания:"
    echo ""
    
    local counter=0
    local jobs_array=()
    
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            counter=$((counter + 1))
            jobs_array+=("$line")
            echo "  $counter. $line"
        fi
    done <<< "$current_jobs"
    
    if [ $counter -eq 0 ]; then
        echo "  ℹ️  Нет активных заданий для удаления"
        return 0
    fi
    
    echo ""
    read -p "Введите номер задания для удаления: " job_num
    
    if [[ ! "$job_num" =~ ^[0-9]+$ ]] || [ "$job_num" -lt 1 ] || [ "$job_num" -gt $counter ]; then
        print_error "Некорректный номер задания: $job_num"
        return 1
    fi
    
    # Создаем бэкап перед изменением
    backup_cron
    
    # Удаляем задание
    local new_jobs=""
    local current_counter=0
    
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            current_counter=$((current_counter + 1))
            if [ "$current_counter" -ne "$job_num" ]; then
                new_jobs+="$line"$'\n'
            fi
        else
            # Сохраняем комментарии и пустые строки
            new_jobs+="$line"$'\n'
        fi
    done <<< "$current_jobs"
    
    if echo "$new_jobs" | crontab -; then
        print_success "Задание $job_num удалено"
        echo "  🗑️  Удалено: ${jobs_array[$((job_num-1))]}"
        log "Удалено cron задание: ${jobs_array[$((job_num-1))]}" "INFO"
    else
        print_error "Ошибка удаления задания"
        return 1
    fi
}

# Включение/отключение задания
toggle_job() {
    local action="$1" # enable или disable
    print_section "$(echo "$action" | tr '[:lower:]' '[:upper:]') ЗАДАНИЯ"
    
    local current_jobs=$(crontab -l 2>/dev/null)
    
    if [ -z "$current_jobs" ]; then
        echo "  ℹ️  Нет заданий"
        return 0
    fi
    
    echo "📋 Текущие задания:"
    echo ""
    
    local counter=0
    local jobs_array=()
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            counter=$((counter + 1))
            jobs_array+=("$line")
            
            if [[ "$line" =~ ^# ]]; then
                echo "  $counter. 💤 [ОТКЛЮЧЕНО] ${line:1}"
            else
                echo "  $counter. ✅ [АКТИВНО] $line"
            fi
        fi
    done <<< "$current_jobs"
    
    if [ $counter -eq 0 ]; then
        echo "  ℹ️  Нет заданий"
        return 0
    fi
    
    echo ""
    read -p "Введите номер задания: " job_num
    
    if [[ ! "$job_num" =~ ^[0-9]+$ ]] || [ "$job_num" -lt 1 ] || [ "$job_num" -gt $counter ]; then
        print_error "Некорректный номер задания: $job_num"
        return 1
    fi
    
    # Создаем бэкап перед изменением
    backup_cron
    
    # Включаем или отключаем задание
    local new_jobs=""
    local current_counter=0
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            current_counter=$((current_counter + 1))
            
            if [ "$current_counter" -eq "$job_num" ]; then
                if [ "$action" == "disable" ] && [[ ! "$line" =~ ^# ]]; then
                    # Отключаем - добавляем комментарий
                    new_jobs+="# $line"$'\n'
                    print_success "Задание отключено"
                    log "Отключено cron задание: $line" "INFO"
                elif [ "$action" == "enable" ] && [[ "$line" =~ ^# ]]; then
                    # Включаем - убираем комментарий
                    new_jobs+="${line:2}"$'\n'
                    print_success "Задание включено"
                    log "Включено cron задание: ${line:2}" "INFO"
                else
                    # Оставляем как есть
                    new_jobs+="$line"$'\n'
                fi
            else
                new_jobs+="$line"$'\n'
            fi
        else
            new_jobs+="$line"$'\n'
        fi
    done <<< "$current_jobs"
    
    if ! echo "$new_jobs" | crontab -; then
        print_error "Ошибка изменения задания"
        return 1
    fi
}

# Поиск заданий
search_jobs() {
    local pattern="$1"
    
    if [ -z "$pattern" ]; then
        read -p "Введите текст для поиска: " pattern
    fi
    
    if [ -z "$pattern" ]; then
        print_error "Не указан текст для поиска"
        return 1
    fi
    
    print_section "ПОИСК ЗАДАНИЙ: '$pattern'"
    
    local user_jobs=$(crontab -l 2>/dev/null)
    local found=0
    
    # Поиск в заданиях пользователя
    if [ -n "$user_jobs" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ $pattern ]]; then
                if [ $found -eq 0 ]; then
                    echo "👤 НАЙДЕНО В ЗАДАНИЯХ ПОЛЬЗОВАТЕЛЯ:"
                    echo ""
                fi
                found=1
                
                if [[ "$line" =~ ^# ]]; then
                    echo "  💤 [ОТКЛЮЧЕНО] ${line:1}"
                else
                    echo "  ✅ [АКТИВНО] $line"
                fi
            fi
        done <<< "$user_jobs"
    fi
    
    # Поиск в системных заданиях
    local cron_dirs=("/etc/cron.d" "/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly")
    local system_found=0
    
    for cron_dir in "${cron_dirs[@]}"; do
        if [ -d "$cron_dir" ]; then
            for file in "$cron_dir"/*; do
                if [ -f "$file" ] && grep -q "$pattern" "$file" 2>/dev/null; then
                    if [ $system_found -eq 0 ]; then
                        echo ""
                        echo "📁 НАЙДЕНО В СИСТЕМНЫХ ЗАДАНИЯХ:"
                        echo ""
                    fi
                    system_found=1
                    echo "  📂 $file:"
                    grep "$pattern" "$file" | while read -r match; do
                        echo "    🔍 $match"
                    done
                fi
            done
        fi
    done
    
    if [ $found -eq 0 ] && [ $system_found -eq 0 ]; then
        echo "  ℹ️  Задания не найдены"
    fi
}

# Восстановление из бэкапа
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        # Показываем доступные бэкапы
        print_section "ДОСТУПНЫЕ БЭКАПЫ"
        
        local backups=($(ls -1t "$BACKUP_DIR"/cron-backup-*.txt 2>/dev/null | head -5))
        
        if [ ${#backups[@]} -eq 0 ]; then
            print_error "Бэкапы не найдены"
            return 1
        fi
        
        echo "Выберите бэкап для восстановления:"
        echo ""
        
        for i in "${!backups[@]}"; do
            local file=$(basename "${backups[$i]}")
            local date_part=$(echo "$file" | sed 's/cron-backup-//' | sed 's/.txt//')
            local pretty_date=$(echo "$date_part" | sed 's/_/ /')
            echo "  $((i+1)). $pretty_date - $file"
        done
        
        echo ""
        read -p "Введите номер бэкапа: " backup_num
        
        if [[ ! "$backup_num" =~ ^[0-9]+$ ]] || [ "$backup_num" -lt 1 ] || [ "$backup_num" -gt ${#backups[@]} ]; then
            print_error "Некорректный номер бэкапа"
            return 1
        fi
        
        backup_file="${backups[$((backup_num-1))]}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    print_section "ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА"
    echo "  📁 Файл: $(basename "$backup_file")"
    
    # Создаем бэкап текущего состояния
    backup_cron
    
    if crontab "$backup_file"; then
        print_success "Cron задания восстановлены из бэкапа"
        log "Восстановлен cron из бэкапа: $backup_file" "INFO"
    else
        print_error "Ошибка восстановления из бэкапа"
        return 1
    fi
}

# Основная функция
main() {
    if ! check_dependencies; then
        exit 1
    fi
    
    case "${1:-}" in
        "list")
            print_header
            list_jobs
            ;;
        "add")
            print_header
            add_job
            ;;
        "remove")
            print_header
            remove_job
            ;;
        "enable")
            print_header
            toggle_job "enable"
            ;;
        "disable")
            print_header
            toggle_job "disable"
            ;;
        "search")
            print_header
            search_jobs "$2"
            ;;
        "edit")
            print_header
            print_section "РЕДАКТИРОВАНИЕ CRONTAB"
            echo "  📝 Открываю редактор..."
            crontab -e
            print_success "Редактирование завершено"
            ;;
        "backup")
            print_header
            backup_cron
            ;;
        "restore")
            print_header
            restore_backup "$2"
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 [КОМАНДА]"
            echo ""
            echo "Команды:"
            echo "  list                   - Список заданий с деталями"
            echo "  add                    - Добавить новое задание"
            echo "  remove                 - Удалить задание"
            echo "  enable                 - Включить отключенное задание"
            echo "  disable                - Отключить задание"
            echo "  search [pattern]       - Поиск заданий"
            echo "  edit                   - Редактировать в редакторе"
            echo "  backup                 - Создать бэкап заданий"
            echo "  restore [file]         - Восстановить из бэкапа"
            echo "  help                   - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 list                # Детальный список"
            echo "  $0 add                 # Интерактивное добавление"
            echo "  $0 remove              # Удаление задания"
            echo "  $0 search backup       # Поиск заданий с 'backup'"
            echo "  $0 disable             # Отключение задания"
            echo "  $0 restore             # Восстановление из бэкапа"
            ;;
        *)
            print_error "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            exit 1
            ;;
    esac
}

main "$@"
