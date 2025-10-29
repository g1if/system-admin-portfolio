#!/bin/bash
# 💾 Умная система резервного копирования с автоопределением
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
BACKUP_DIR="$PROJECT_ROOT/backups"
CONFIG_DIR="$PROJECT_ROOT/configs"
PACKAGE_BACKUP_DIR="$BACKUP_DIR/package-backups"
LOG_FILE="$LOG_DIR/backup-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$CONFIG_DIR" "$PACKAGE_BACKUP_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Конфигурация по умолчанию
CONFIG_FILE="$CONFIG_DIR/backup.conf"

# Логирование
log() {
    local level=${2:-"INFO"}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "💾 ==========================================="
    echo "   МЕНЕДЖЕР РЕЗЕРВНОГО КОПИРОВАНИЯ v2.0"
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
    local missing=()
    local optional_missing=()
    
    # Обязательные зависимости
    for cmd in tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Опциональные зависимости для сжатия
    if ! command -v gzip &> /dev/null; then
        optional_missing+=("gzip")
    fi
    
    if ! command -v pigz &> /dev/null; then
        optional_missing+=("pigz")
    fi
    
    if ! command -v bzip2 &> /dev/null; then
        optional_missing+=("bzip2")
    fi
    
    if ! command -v xz &> /dev/null; then
        optional_missing+=("xz")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите: sudo apt install ${missing[*]}"
        return 1
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        print_warning "Отсутствуют опциональные утилиты сжатия: ${optional_missing[*]}"
        echo "💡 Для лучшего сжатия установите: sudo apt install ${optional_missing[*]}"
    fi
    
    return 0
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена: $CONFIG_FILE"
    else
        # Конфигурация по умолчанию
        BACKUP_SOURCES=("/etc" "$HOME/projects")
        BACKUP_RETENTION_DAYS=7
        BACKUP_COMPRESSION="auto"
        BACKUP_PREFIX="system-backup"
        BACKUP_EXCLUDES=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*" "*.iso" "*.ova" "*.vmdk")
        ENABLE_INCREMENTAL=false
        INCREMENTAL_LEVEL=1
        ENABLE_PACKAGE_BACKUP=true
        NOTIFICATION_METHODS=("log" "console")
        LOG_RETENTION_DAYS=30
        
        print_warning "Используется конфигурация по умолчанию"
        log "Используется конфигурация по умолчанию" "WARNING"
    fi
}

# Создание конфигурационного файла
create_config() {
    cat > "$CONFIG_FILE" << 'CONFIG_EOF'
# Конфигурация менеджера резервного копирования v2.0
# Автоматически создано: $(date)

# Директории для резервного копирования
BACKUP_SOURCES=("/etc" "$HOME/projects" "/var/www")

# Срок хранения бэкапов (в днях)
BACKUP_RETENTION_DAYS=7

# Метод сжатия (auto, gzip, bzip2, xz, pigz, none)
BACKUP_COMPRESSION="auto"

# Префикс для файлов бэкапов
BACKUP_PREFIX="system-backup"

# Исключения (шаблоны для исключения из бэкапа)
BACKUP_EXCLUDES=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*" "*.iso" "*.ova" "*.vmdk" "*.docker/*")

# Инкрементальные бэкапы
ENABLE_INCREMENTAL=false
INCREMENTAL_LEVEL=1

# Бэкап списка установленных пакетов
ENABLE_PACKAGE_BACKUP=true

# Методы уведомлений
NOTIFICATION_METHODS=("log" "console")

# Срок хранения логов (дни)
LOG_RETENTION_DAYS=30
CONFIG_EOF
    
    print_success "Создан файл конфигурации: $CONFIG_FILE"
    log "Создан конфигурационный файл" "INFO"
}

# Проверка доступности источников
check_sources() {
    local valid_sources=()
    local need_sudo=0
    
    print_section "ПРОВЕРКА ИСТОЧНИКОВ"
    
    for source in "${BACKUP_SOURCES[@]}"; do
        # Разрешаем переменные в путях (например $HOME)
        eval source_expanded="$source"
        
        if [ -e "$source_expanded" ]; then
            # Проверяем права доступа
            if [ -r "$source_expanded" ]; then
                valid_sources+=("$source_expanded")
                echo "  ✅ Доступен: $source_expanded"
                
                # Проверяем, нужны ли права sudo для системных файлов
                if [[ "$source_expanded" == "/etc"* ]] || [[ "$source_expanded" == "/var"* ]] || [[ "$source_expanded" == "/root"* ]]; then
                    if [ ! -r "$source_expanded" ] || [ "$(stat -c %U "$source_expanded" 2>/dev/null)" != "$USER" ]; then
                        need_sudo=1
                    fi
                fi
            else
                print_warning "Нет прав на чтение: $source_expanded"
                # Для системных файлов пробуем с sudo
                if [[ "$source_expanded" == "/etc"* ]] || [[ "$source_expanded" == "/var"* ]]; then
                    if sudo test -r "$source_expanded"; then
                        valid_sources+=("$source_expanded")
                        need_sudo=1
                        echo "  ✅ Доступен (требуется sudo): $source_expanded"
                    else
                        print_warning "Нет прав даже с sudo: $source_expanded"
                    fi
                fi
            fi
        else
            print_warning "Источник не найден: $source_expanded"
        fi
    done
    
    if [ ${#valid_sources[@]} -eq 0 ]; then
        print_error "Нет доступных источников для бэкапа"
        return 1
    fi
    
    # Возвращаем массив valid_sources и флаг need_sudo
    echo "${valid_sources[@]}"
    return $need_sudo
}

# Определение лучшего метода сжатия
detect_compression() {
    case "$BACKUP_COMPRESSION" in
        "auto")
            if command -v pigz >/dev/null 2>&1; then
                echo "pigz"
            elif command -v gzip >/dev/null 2>&1; then
                echo "gzip"
            elif command -v bzip2 >/dev/null 2>&1; then
                echo "bzip2"
            elif command -v xz >/dev/null 2>&1; then
                echo "xz"
            else
                echo "none"
            fi
            ;;
        "gzip"|"bzip2"|"xz"|"pigz"|"none")
            echo "$BACKUP_COMPRESSION"
            ;;
        *)
            print_warning "Неизвестный метод сжатия: $BACKUP_COMPRESSION, используется auto"
            detect_compression "auto"
            ;;
    esac
}

# Человеко-читаемый размер
human_size() {
    local bytes=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B "$bytes"
    elif command -v bc >/dev/null 2>&1; then
        if [ "$bytes" -gt 1073741824 ]; then
            echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
        elif [ "$bytes" -gt 1048576 ]; then
            echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
        elif [ "$bytes" -gt 1024 ]; then
            echo "$(echo "scale=2; $bytes/1024" | bc) KB"
        else
            echo "$bytes bytes"
        fi
    else
        # Простой вывод
        if [ "$bytes" -gt 1073741824 ]; then
            echo "$((bytes / 1073741824)) GB"
        elif [ "$bytes" -gt 1048576 ]; then
            echo "$((bytes / 1048576)) MB"
        elif [ "$bytes" -gt 1024 ]; then
            echo "$((bytes / 1024)) KB"
        else
            echo "$bytes bytes"
        fi
    fi
}

# Проверка свободного места
check_disk_space() {
    local required_space=$1
    local backup_dir=$2
    
    if ! command -v df >/dev/null 2>&1; then
        print_warning "Не могу проверить свободное место (df не найден)"
        return 0
    fi
    
    local available_space=$(df "$backup_dir" | awk 'NR==2 {print $4 * 1024}')
    local available_human=$(human_size "$available_space")
    local required_human=$(human_size "$required_space")
    
    echo "  💾 Свободно места: $available_human"
    echo "  📦 Требуется: $required_human"
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Недостаточно свободного места!"
        echo "  💡 Очистите место или измените директорию бэкапов"
        return 1
    fi
    
    return 0
}

# Оценка размера бэкапа
estimate_backup_size() {
    local sources=("$@")
    local total_size=0
    
    for source in "${sources[@]}"; do
        if [ -e "$source" ]; then
            # Используем du для оценки размера, исключая указанные паттерны
            local size_cmd=("du" "-sb" "$source")
            
            # Добавляем исключения если возможно
            if command -v find >/dev/null 2>&1 && [ ${#BACKUP_EXCLUDES[@]} -gt 0 ]; then
                local exclude_args=()
                for exclude in "${BACKUP_EXCLUDES[@]}"; do
                    exclude_args+=(-name "$exclude" -o)
                done
                # Удаляем последний -o
                unset 'exclude_args[${#exclude_args[@]}-1]'
                
                # Оценка через find + du
                local source_size=$(find "$source" \( "${exclude_args[@]}" \) -prune -o -type f -print0 | du -sb --files0-from=- | awk '{total += $1} END {print total}')
                total_size=$((total_size + ${source_size:-0}))
            else
                # Простая оценка через du
                local source_size=$(du -sb "$source" 2>/dev/null | awk '{print $1}')
                total_size=$((total_size + ${source_size:-0}))
            fi
        fi
    done
    
    echo "$total_size"
}

# Бэкап списка пакетов
backup_packages() {
    if [ "$ENABLE_PACKAGE_BACKUP" != "true" ]; then
        return 0
    fi
    
    print_section "БЭКАП СПИСКА ПАКЕТОВ"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local package_file="$PACKAGE_BACKUP_DIR/packages_${timestamp}.list"
    
    # Для Debian/Ubuntu
    if command -v dpkg >/dev/null 2>&1; then
        echo "  🐧 Экспорт списка пакетов dpkg..."
        dpkg --get-selections > "$package_file"
        print_success "Список пакетов dpkg сохранен: $(basename "$package_file")"
    fi
    
    # Для RedHat/CentOS
    if command -v rpm >/dev/null 2>&1; then
        echo "  🔴 Экспорт списка пакетов rpm..."
        rpm -qa > "${package_file}.rpm"
        print_success "Список пакетов rpm сохранен: $(basename "${package_file}.rpm")"
    fi
    
    # Для Arch Linux
    if command -v pacman >/dev/null 2>&1; then
        echo "  🎯 Экспорт списка пакетов pacman..."
        pacman -Qqe > "${package_file}.pacman"
        print_success "Список пакетов pacman сохранен: $(basename "${package_file}.pacman")"
    fi
    
    # Для Snap
    if command -v snap >/dev/null 2>&1; then
        echo "  ⭕ Экспорт списка snap пакетов..."
        snap list > "${package_file}.snap" 2>/dev/null || true
    fi
    
    # Для Flatpak
    if command -v flatpak >/dev/null 2>&1; then
        echo "  📦 Экспорт списка flatpak пакетов..."
        flatpak list > "${package_file}.flatpak" 2>/dev/null || true
    fi
}

# Создание бэкапа
create_backup() {
    if ! check_dependencies; then
        print_error "Проверка зависимостей не пройдена"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${BACKUP_PREFIX:-backup}_${timestamp}"
    local backup_file="$BACKUP_DIR/${backup_name}.tar"
    
    print_header
    log "Начало создания бэкапа: $backup_name" "INFO"
    
    # Проверка источников
    local check_result
    check_result=$(check_sources)
    local need_sudo=$?
    IFS=' ' read -r -a valid_sources <<< "$check_result"
    
    if [ ${#valid_sources[@]} -eq 0 ]; then
        print_error "Нет доступных источников для бэкапа"
        echo "  💡 Проверьте конфигурацию в: $CONFIG_FILE"
        return 1
    fi
    
    # Оценка размера
    print_section "ОЦЕНКА РАЗМЕРА"
    local estimated_size=$(estimate_backup_size "${valid_sources[@]}")
    local estimated_size_human=$(human_size "$estimated_size")
    echo "  📐 Примерный размер бэкапа: $estimated_size_human"
    
    # Проверка свободного места (с запасом 20%)
    local required_space=$((estimated_size * 120 / 100))
    if ! check_disk_space "$required_space" "$BACKUP_DIR"; then
        return 1
    fi
    
    # Бэкап пакетов
    backup_packages
    
    # Создание архива
    print_section "СОЗДАНИЕ АРХИВА"
    echo "  📦 Создание архива: $(basename "$backup_file")"
    
    # Строим команду tar
    local tar_cmd=("tar" "-cf" "$backup_file" "--ignore-failed-read")
    
    # Добавляем исключения
    if [ ${#BACKUP_EXCLUDES[@]} -gt 0 ]; then
        for exclude in "${BACKUP_EXCLUDES[@]}"; do
            tar_cmd+=("--exclude=$exclude")
        done
        echo "  🚫 Исключения: ${BACKUP_EXCLUDES[*]}"
    fi
    
    # Добавляем источники
    for source in "${valid_sources[@]}"; do
        tar_cmd+=("$source")
    done
    
    echo "  🔄 Выполнение: tar -cf ... (источников: ${#valid_sources[@]})"
    
    # Выполняем команду с sudo если нужно
    local tar_success=0
    if [ $need_sudo -eq 1 ]; then
        echo "  🔑 Используем sudo для доступа к системным файлам..."
        if sudo "${tar_cmd[@]}" 2>> "$LOG_FILE"; then
            tar_success=1
        else
            print_error "Ошибка создания архива с sudo"
            log "Ошибка создания архива с sudo. Команда: ${tar_cmd[*]}" "ERROR"
        fi
    else
        if "${tar_cmd[@]}" 2>> "$LOG_FILE"; then
            tar_success=1
        else
            print_error "Ошибка создания архива"
            log "Ошибка создания архива. Команда: ${tar_cmd[*]}" "ERROR"
        fi
    fi
    
    if [ $tar_success -eq 0 ]; then
        # Удаляем частично созданный файл
        if [ -f "$backup_file" ]; then
            rm -f "$backup_file"
        fi
        return 1
    fi
    
    local size=0
    if [ -f "$backup_file" ]; then
        size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
    fi
    echo "  ✅ Архив создан: $(human_size $size)"
    log "Архив создан: $backup_file ($(human_size $size))" "INFO"
    
    # Сжатие
    local compression_tool=$(detect_compression)
    local final_file="$backup_file"
    
    print_section "СЖАТИЕ"
    case $compression_tool in
        "pigz")
            echo "  🔄 Сжатие с pigz (многопоточное)..."
            if pigz "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.gz"
                echo "  ✅ Сжатие pigz завершено"
            else
                print_warning "Ошибка сжатия pigz, оставляем несжатым"
            fi
            ;;
        "gzip")
            echo "  🔄 Сжатие с gzip..."
            if gzip "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.gz"
                echo "  ✅ Сжатие gzip завершено"
            else
                print_warning "Ошибка сжатия gzip, оставляем несжатым"
            fi
            ;;
        "bzip2")
            echo "  🔄 Сжатие с bzip2..."
            if bzip2 "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.bz2"
                echo "  ✅ Сжатие bzip2 завершено"
            else
                print_warning "Ошибка сжатия bzip2, оставляем несжатым"
            fi
            ;;
        "xz")
            echo "  🔄 Сжатие с xz..."
            if xz "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.xz"
                echo "  ✅ Сжатие xz завершено"
            else
                print_warning "Ошибка сжатия xz, оставляем несжатым"
            fi
            ;;
        *)
            echo "  ℹ️  Сжатие не применяется"
            ;;
    esac
    
    local final_size=0
    if [ -f "$final_file" ]; then
        final_size=$(stat -c%s "$final_file" 2>/dev/null || echo 0)
    fi
    
    if [ $final_size -gt 0 ]; then
        local compression_ratio="N/A"
        if [ $size -gt 0 ]; then
            compression_ratio=$(echo "scale=2; $size / $final_size" | bc 2>/dev/null || echo "N/A")
        fi
        
        print_success "Бэкап создан: $(basename $final_file) ($(human_size $final_size))"
        if [ "$compression_ratio" != "N/A" ]; then
            echo "  📈 Коэффициент сжатия: ${compression_ratio}x"
        fi
        
        log "Бэкап создан: $final_file ($(human_size $final_size)), сжатие: $compression_tool" "SUCCESS"
        
        # Информация о бэкапе
        echo ""
        echo -e "${BLUE}📋 ИНФОРМАЦИЯ О БЭКАПЕ:${NC}"
        echo "  Файл: $(basename $final_file)"
        echo "  Размер: $(human_size $final_size)"
        echo "  Дата: $(date)"
        echo "  Источники: ${valid_sources[*]}"
        echo "  Сжатие: $compression_tool"
        if [ "$compression_ratio" != "N/A" ]; then
            echo "  Коэффициент сжатия: ${compression_ratio}x"
        fi
        echo "  Директория: $BACKUP_DIR"
    else
        print_error "Бэкап не был создан"
        return 1
    fi
}

# Очистка старых бэкапов
clean_old_backups() {
    print_section "ОЧИСТКА СТАРЫХ БЭКАПОВ"
    
    local retention_days=${BACKUP_RETENTION_DAYS:-7}
    local deleted_count=0
    local freed_space=0
    
    echo "  🗑️  Поиск бэкапов старше $retention_days дней..."
    
    # Используем while read для безопасной обработки файлов
    while IFS= read -r -d '' backup; do
        if [ -f "$backup" ] && [[ "$(basename "$backup")" =~ ^${BACKUP_PREFIX}.*$ ]]; then
            local size=$(stat -c%s "$backup" 2>/dev/null || echo 0)
            echo "  Удаление: $(basename "$backup") ($(human_size $size))"
            freed_space=$((freed_space + size))
            deleted_count=$((deleted_count + 1))
            rm -f "$backup"
            log "Удален бэкап: $backup ($(human_size $size))" "INFO"
        fi
    done < <(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*" -type f -mtime "+$retention_days" -print0 2>/dev/null)
    
    # Очистка старых логов
    local log_retention_days=${LOG_RETENTION_DAYS:-30}
    if [ -f "$LOG_FILE" ]; then
        echo "  🧹 Очистка логов старше $log_retention_days дней..."
        # Создаем временный файл с актуальными логами
        local temp_log=$(mktemp)
        local cutoff_date=$(date -d "$log_retention_days days ago" +%Y-%m-%d)
        
        while IFS= read -r line; do
            local log_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
            if [[ "$log_date" > "$cutoff_date" ]] || [[ "$log_date" == "$cutoff_date" ]]; then
                echo "$line" >> "$temp_log"
            fi
        done < "$LOG_FILE"
        
        mv "$temp_log" "$LOG_FILE"
        echo "  ✅ Логи очищены"
    fi
    
    if [ $deleted_count -gt 0 ]; then
        print_success "Удалено бэкапов: $deleted_count"
        echo "  📊 Освобождено места: $(human_size $freed_space)"
        log "Очистка бэкапов: удалено $deleted_count файлов, освобождено $(human_size $freed_space)" "INFO"
    else
        echo "  ℹ️  Старые бэкапы не найдены"
    fi
}

# Статистика бэкапов
show_stats() {
    print_section "СТАТИСТИКА БЭКАПОВ"
    
    local total_size=0
    local total_files=0
    local latest_backup=""
    local latest_date=""
    
    # Проверяем есть ли файлы в директории
    if [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        for backup in "$BACKUP_DIR"/*; do
            if [ -f "$backup" ] && [[ "$(basename "$backup")" =~ ^${BACKUP_PREFIX}.*$ ]]; then
                local size=0
                size=$(stat -c%s "$backup" 2>/dev/null || echo 0)
                total_size=$((total_size + size))
                total_files=$((total_files + 1))
                
                # Находим самый свежий бэкап
                local backup_date=$(stat -c %Y "$backup" 2>/dev/null || echo 0)
                if [ -z "$latest_date" ] || [ "$backup_date" -gt "$latest_date" ]; then
                    latest_date=$backup_date
                    latest_backup=$(basename "$backup")
                fi
                
                echo "  📄 $(basename "$backup") - $(human_size $size)"
            fi
        done
    else
        echo "  ℹ️  Бэкапы не найдены"
    fi
    
    echo ""
    echo -e "${BLUE}📊 ОБЩАЯ СТАТИСТИКА:${NC}"
    echo "  Всего бэкапов: $total_files"
    echo "  Общий размер: $(human_size $total_size)"
    
    if [ -n "$latest_backup" ]; then
        echo "  Последний бэкап: $latest_backup"
        echo "  Дата последнего бэкапа: $(date -d "@$latest_date" '+%Y-%m-%d %H:%M:%S')"
    fi
    
    echo "  Директория: $BACKUP_DIR"
    
    # Информация о свободном месте
    if command -v df >/dev/null 2>&1; then
        local available_space=$(df "$BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo 0)
        echo "  Свободно места: $(human_size $available_space)"
    fi
    
    # Статистика пакетных бэкапов
    if [ "$ENABLE_PACKAGE_BACKUP" = "true" ] && [ -d "$PACKAGE_BACKUP_DIR" ]; then
        local package_files=0
        local package_size=0
        
        for pkg_file in "$PACKAGE_BACKUP_DIR"/*; do
            if [ -f "$pkg_file" ]; then
                package_files=$((package_files + 1))
                package_size=$((package_size + $(stat -c%s "$pkg_file" 2>/dev/null || echo 0)))
            fi
        done
        
        if [ $package_files -gt 0 ]; then
            echo ""
            echo -e "${GREEN}📦 СТАТИСТИКА ПАКЕТНЫХ БЭКАПОВ:${NC}"
            echo "  Файлов пакетов: $package_files"
            echo "  Общий размер: $(human_size $package_size)"
            echo "  Директория: $PACKAGE_BACKUP_DIR"
        fi
    fi
}

# Восстановление из бэкапа
restore_backup() {
    local backup_file="$1"
    local restore_dir="${2:-./restored}"
    
    if [ ! -f "$backup_file" ]; then
        print_error "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    print_section "ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА"
    echo "  Файл: $(basename "$backup_file")"
    echo "  Целевая директория: $restore_dir"
    
    mkdir -p "$restore_dir"
    
    # Определение типа архива и распаковка
    local restore_cmd=""
    case "$backup_file" in
        *.tar.gz|*.tgz)
            echo "  📦 Распаковка gzip архива..."
            restore_cmd="tar -xzf \"$backup_file\" -C \"$restore_dir\""
            ;;
        *.tar.bz2)
            echo "  📦 Распаковка bzip2 архива..."
            restore_cmd="tar -xjf \"$backup_file\" -C \"$restore_dir\""
            ;;
        *.tar.xz)
            echo "  📦 Распаковка xz архива..."
            restore_cmd="tar -xJf \"$backup_file\" -C \"$restore_dir\""
            ;;
        *.tar)
            echo "  📦 Распаковка tar архива..."
            restore_cmd="tar -xf \"$backup_file\" -C \"$restore_dir\""
            ;;
        *)
            print_error "Неизвестный формат архива: $backup_file"
            return 1
            ;;
    esac
    
    if eval $restore_cmd; then
        local restored_count=0
        if command -v find >/dev/null 2>&1; then
            restored_count=$(find "$restore_dir" -type f 2>/dev/null | wc -l)
        fi
        print_success "Восстановление завершено"
        echo "  📁 Восстановлено файлов: $restored_count"
        echo "  📂 Директория: $restore_dir"
        log "Восстановление из $backup_file в $restore_dir (файлов: $restored_count)" "SUCCESS"
    else
        print_error "Ошибка восстановления из бэкапа"
        return 1
    fi
}

# Восстановление пакетов
restore_packages() {
    local package_file="$1"
    
    if [ ! -f "$package_file" ]; then
        print_error "Файл пакетов не найден: $package_file"
        return 1
    fi
    
    print_section "ВОССТАНОВЛЕНИЕ ПАКЕТОВ"
    echo "  Файл: $(basename "$package_file")"
    
    # Определяем тип файла пакетов
    case "$package_file" in
        *.list)
            if command -v dpkg >/dev/null 2>&1; then
                echo "  🐧 Восстановление пакетов dpkg..."
                sudo dpkg --set-selections < "$package_file"
                sudo apt-get dselect-upgrade -y
                print_success "Пакеты dpkg восстановлены"
            fi
            ;;
        *.rpm)
            if command -v rpm >/dev/null 2>&1; then
                echo "  🔴 Восстановление пакетов rpm..."
                # Для rpm обычно нужно переустановить систему
                print_warning "RPM пакеты экспортированы, но автоматическое восстановление не поддерживается"
                echo "  💡 Файл для ручного восстановления: $package_file"
            fi
            ;;
        *.pacman)
            if command -v pacman >/dev/null 2>&1; then
                echo "  🎯 Восстановление пакетов pacman..."
                sudo pacman -S --needed - < "$package_file"
                print_success "Пакеты pacman восстановлены"
            fi
            ;;
        *)
            print_warning "Неизвестный формат файла пакетов: $package_file"
            ;;
    esac
}

# Основная функция
main() {
    load_config
    
    case "${1:-}" in
        "create")
            create_backup
            ;;
        "clean")
            clean_old_backups
            ;;
        "stats")
            show_stats
            ;;
        "restore")
            if [ -z "${2:-}" ]; then
                print_error "Укажите файл бэкапа для восстановления"
                echo "Использование: $0 restore <backup-file> [restore-dir]"
                return 1
            fi
            restore_backup "$2" "${3:-}"
            ;;
        "restore-packages")
            if [ -z "${2:-}" ]; then
                print_error "Укажите файл пакетов для восстановления"
                echo "Использование: $0 restore-packages <package-file>"
                return 1
            fi
            restore_packages "$2"
            ;;
        "config")
            create_config
            ;;
        "list")
            echo -e "${BLUE}📁 ДОСТУПНЫЕ БЭКАПЫ:${NC}"
            ls -la "$BACKUP_DIR" 2>/dev/null | grep -v "total" | grep -v ".gitkeep" || echo "  ℹ️  Бэкапы не найдены"
            ;;
        "list-packages")
            echo -e "${BLUE}📦 ДОСТУПНЫЕ БЭКАПЫ ПАКЕТОВ:${NC}"
            ls -la "$PACKAGE_BACKUP_DIR" 2>/dev/null | grep -v "total" || echo "  ℹ️  Бэкапы пакетов не найдены"
            ;;
        "help"|"--help"|"-h"|"")
            print_header
            echo "Использование: $0 {create|clean|stats|restore|restore-packages|config|list|list-packages|help}"
            echo ""
            echo "Команды:"
            echo "  create                   - Создать новый бэкап"
            echo "  clean                    - Очистить старые бэкапы"
            echo "  stats                    - Показать статистику"
            echo "  restore <file> [dir]     - Восстановить из бэкапа"
            echo "  restore-packages <file>  - Восстановить пакеты из файла"
            echo "  config                   - Создать конфигурационный файл"
            echo "  list                     - Список бэкапов"
            echo "  list-packages            - Список бэкапов пакетов"
            echo "  help                     - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 create"
            echo "  $0 restore backups/backup_20231022.tar.gz ./restored"
            echo "  $0 restore-packages backups/package-backups/packages_20231022.list"
            echo "  $0 stats"
            echo "  $0 config"
            ;;
        *)
            print_error "Неизвестная команда: $1"
            echo "Используйте: $0 help"
            return 1
            ;;
    esac
}

main "$@"
