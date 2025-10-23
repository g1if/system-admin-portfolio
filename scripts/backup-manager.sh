#!/bin/bash
# 💾 Умная система резервного копирования с автоопределением
# Автор: g1if
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -euo pipefail

# Определяем абсолютный путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
BACKUP_DIR="$PROJECT_ROOT/backups"
CONFIG_DIR="$PROJECT_ROOT/configs"
LOG_FILE="$LOG_DIR/backup-manager.log"

# Создаем директории
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$CONFIG_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Конфигурация по умолчанию
CONFIG_FILE="$CONFIG_DIR/backup.conf"

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}"
    echo "💾 ==========================================="
    echo "   МЕНЕДЖЕР РЕЗЕРВНОГО КОПИРОВАНИЯ v1.1"
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Конфигурация загружена: $CONFIG_FILE"
    else
        # Конфигурация по умолчанию
        BACKUP_SOURCES=("/etc" "$HOME/projects")
        BACKUP_RETENTION_DAYS=3
        BACKUP_COMPRESSION="gzip"
        BACKUP_PREFIX="backup"
        BACKUP_EXCLUDES=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*")
        log "Используется конфигурация по умолчанию"
    fi
}

# Создание конфигурационного файла
create_config() {
    cat > "$CONFIG_FILE" << 'CONFIG_EOF'
# Конфигурация менеджера резервного копирования
# Автоматически создано: $(date)

# Директории для резервного копирования (меньший размер для тестирования)
BACKUP_SOURCES=("/etc" "$HOME/projects")

# Срок хранения бэкапов (в днях)
BACKUP_RETENTION_DAYS=3

# Метод сжатия (gzip, bzip2, xz, none)
BACKUP_COMPRESSION="gzip"

# Префикс для файлов бэкапов
BACKUP_PREFIX="system-backup"

# Исключения (шаблоны для исключения из бэкапа)
BACKUP_EXCLUDES=("*.tmp" "*.log" "cache/*" "node_modules/*" ".git/*" "*.iso" "*.ova" "*.vmdk")
CONFIG_EOF
    
    print_success "Создан файл конфигурации: $CONFIG_FILE"
}

# Определение лучшего метода сжатия
detect_compression() {
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
}

# Человеко-читаемый размер
human_size() {
    local bytes=$1
    if command -v bc >/dev/null 2>&1; then
        if [ $bytes -gt 1073741824 ]; then
            echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
        elif [ $bytes -gt 1048576 ]; then
            echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
        elif [ $bytes -gt 1024 ]; then
            echo "$(echo "scale=2; $bytes/1024" | bc) KB"
        else
            echo "$bytes bytes"
        fi
    else
        # Простой вывод если bc не установлен
        if [ $bytes -gt 1073741824 ]; then
            echo "$((bytes / 1073741824)) GB"
        elif [ $bytes -gt 1048576 ]; then
            echo "$((bytes / 1048576)) MB"
        elif [ $bytes -gt 1024 ]; then
            echo "$((bytes / 1024)) KB"
        else
            echo "$bytes bytes"
        fi
    fi
}

# Создание бэкапа
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${BACKUP_PREFIX:-backup}_${timestamp}"
    local backup_file="$BACKUP_DIR/${backup_name}.tar"
    
    print_header
    log "Начало создания бэкапа: $backup_name"
    
    # Проверка источников
    local valid_sources=()
    for source in "${BACKUP_SOURCES[@]}"; do
        # Разрешаем переменные в путях (например $HOME)
        eval source_expanded="$source"
        if [ -e "$source_expanded" ]; then
            valid_sources+=("$source_expanded")
            echo "  📁 Добавлено: $source_expanded"
        else
            print_warning "Источник не найден: $source_expanded"
        fi
    done
    
    if [ ${#valid_sources[@]} -eq 0 ]; then
        print_error "Нет действительных источников для бэкапа"
        return 1
    fi
    
    # Создание архива с исключениями
    echo "  🗜️  Создание архива..."
    
    # Строим команду tar с исключениями
    local tar_cmd="tar -cf \"$backup_file\""
    
    # Добавляем исключения если они есть
    if [ ${#BACKUP_EXCLUDES[@]} -gt 0 ]; then
        for exclude in "${BACKUP_EXCLUDES[@]}"; do
            tar_cmd="$tar_cmd --exclude=\"$exclude\""
        done
    fi
    
    # Добавляем источники
    tar_cmd="$tar_cmd ${valid_sources[@]}"
    
    # Выполняем команду
    if eval $tar_cmd 2>/dev/null; then
        local size=0
        if [ -f "$backup_file" ]; then
            size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
        fi
        echo "  📦 Архив создан: $(human_size $size)"
        log "Архив создан: $backup_file ($(human_size $size))"
    else
        print_error "Ошибка создания архива"
        log "Ошибка создания архива: $backup_file"
        
        # Удаляем частично созданный файл
        if [ -f "$backup_file" ]; then
            rm -f "$backup_file"
        fi
        return 1
    fi
    
    # Сжатие
    local compression_tool=$(detect_compression)
    local final_file="$backup_file"
    
    case $compression_tool in
        "pigz")
            echo "  🔄 Сжатие с pigz (многопоточное)..."
            if pigz "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.gz"
            else
                print_warning "Ошибка сжатия pigz, оставляем несжатым"
            fi
            ;;
        "gzip")
            echo "  🔄 Сжатие с gzip..."
            if gzip "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.gz"
            else
                print_warning "Ошибка сжатия gzip, оставляем несжатым"
            fi
            ;;
        "bzip2")
            echo "  🔄 Сжатие с bzip2..."
            if bzip2 "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.bz2"
            else
                print_warning "Ошибка сжатия bzip2, оставляем несжатым"
            fi
            ;;
        "xz")
            echo "  🔄 Сжатие с xz..."
            if xz "$backup_file" 2>/dev/null; then
                final_file="${backup_file}.xz"
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
        print_success "Бэкап создан: $(basename $final_file) ($(human_size $final_size))"
        log "Бэкап создан: $final_file ($(human_size $final_size))"
        
        # Информация о бэкапе
        echo ""
        echo -e "${BLUE}📋 ИНФОРМАЦИЯ О БЭКАПЕ:${NC}"
        echo "  Файл: $(basename $final_file)"
        echo "  Размер: $(human_size $final_size)"
        echo "  Дата: $(date)"
        echo "  Источники: ${valid_sources[*]}"
        echo "  Сжатие: $compression_tool"
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
    find "$BACKUP_DIR" -name "${BACKUP_PREFIX:-backup}_*" -type f -mtime "+$retention_days" | while read -r backup; do
        if [ -f "$backup" ]; then
            local size=$(stat -c%s "$backup" 2>/dev/null || echo 0)
            echo "  Удаление: $(basename "$backup") ($(human_size $size))"
            freed_space=$((freed_space + size))
            deleted_count=$((deleted_count + 1))
            rm -f "$backup"
            log "Удален бэкап: $backup ($(human_size $size))"
        fi
    done
    
    if [ $deleted_count -gt 0 ]; then
        print_success "Удалено бэкапов: $deleted_count"
        echo "  📊 Освобождено места: $(human_size $freed_space)"
        log "Очистка бэкапов: удалено $deleted_count файлов, освобождено $(human_size $freed_space)"
    else
        echo "  ℹ️  Старые бэкапы не найдены"
    fi
}

# Статистика бэкапов
show_stats() {
    print_section "СТАТИСТИКА БЭКАПОВ"
    
    local total_size=0
    local total_files=0
    
    # Проверяем есть ли файлы в директории
    if [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        for backup in "$BACKUP_DIR"/*; do
            if [ -f "$backup" ] && [ "$(basename "$backup")" != ".gitkeep" ]; then
                local size=0
                size=$(stat -c%s "$backup" 2>/dev/null || echo 0)
                total_size=$((total_size + size))
                total_files=$((total_files + 1))
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
    echo "  Директория: $BACKUP_DIR"
    
    # Информация о свободном месте
    if command -v df >/dev/null 2>&1; then
        local available_space=$(df "$BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo 0)
        echo "  Свободно места: $(human_size $available_space)"
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
        log "Восстановление из $backup_file в $restore_dir (файлов: $restored_count)"
    else
        print_error "Ошибка восстановления из бэкапа"
        return 1
    fi
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
        "config")
            create_config
            ;;
        "list")
            echo -e "${BLUE}📁 ДОСТУПНЫЕ БЭКАПЫ:${NC}"
            ls -la "$BACKUP_DIR" 2>/dev/null | grep -v "total" | grep -v ".gitkeep" || echo "  ℹ️  Бэкапы не найдены"
            ;;
        "help"|"")
            print_header
            echo "Использование: $0 {create|clean|stats|restore|config|list|help}"
            echo ""
            echo "Команды:"
            echo "  create                   - Создать новый бэкап"
            echo "  clean                    - Очистить старые бэкапы"
            echo "  stats                    - Показать статистику"
            echo "  restore <file> [dir]     - Восстановить из бэкапа"
            echo "  config                   - Создать конфигурационный файл"
            echo "  list                     - Список бэкапов"
            echo "  help                     - Эта справка"
            echo ""
            echo "Примеры:"
            echo "  $0 create"
            echo "  $0 restore backups/backup_20231022.tar.gz ./restored"
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
