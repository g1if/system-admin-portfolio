#!/bin/bash
# 🔧 Продвинутый Git помощник для управления репозиториями
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
LOG_FILE="$LOG_DIR/git-helper.log"

mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
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
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO" "$1"
}

print_header() {
    echo -e "${CYAN}"
    echo "🔧 ==========================================="
    echo "   ПРОДВИНУТЫЙ GIT ПОМОЩНИК v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

# Проверка наличия Git
check_git_installed() {
    if ! command -v git &> /dev/null; then
        print_error "Git не установлен. Установите: sudo apt install git"
        exit 1
    fi
}

# Проверка Git репозитория
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Текущая директория не является Git репозиторием"
        return 1
    fi
    return 0
}

# Получение информации о репозитории
get_repo_info() {
    local repo_name=$(basename -s .git $(git config --get remote.origin.url 2>/dev/null) 2>/dev/null || echo "N/A")
    local current_branch=$(git branch --show-current 2>/dev/null || echo "N/A")
    local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "N/A")
    
    echo "  📁 Репозиторий: $repo_name"
    echo "  🌿 Ветка: $current_branch"
    echo "  🌐 Удаленный: $remote_url"
}

# Статус репозитория с детальной информацией
cmd_status() {
    print_header
    print_info "Статус репозитория"
    
    if ! check_git_repo; then
        return 1
    fi
    
    get_repo_info
    echo ""
    
    # Детальный статус
    git status
    
    # Количество коммитов вперед/позади
    local ahead_behind=$(git rev-list --left-right --count HEAD...origin/$(git branch --show-current) 2>/dev/null || echo "0 0")
    local ahead=$(echo $ahead_behind | awk '{print $1}')
    local behind=$(echo $ahead_behind | awk '{print $2}')
    
    if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        echo ""
        echo "  📊 Синхронизация с удаленным репозиторием:"
        echo "    📤 Впереди на $ahead коммитов"
        echo "    📥 Позади на $behind коммитов"
    fi
}

# Умный коммит с проверками
cmd_commit() {
    local message="${2:-}"
    local type="${3:-feat}"
    
    print_header
    print_info "Подготовка коммита"
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [ -z "$message" ]; then
        print_error "Укажите сообщение коммита"
        echo "Использование: $0 commit \"сообщение\" [тип]"
        echo "Типы: feat, fix, docs, style, refactor, test, chore"
        return 1
    fi
    
    get_repo_info
    echo ""
    
    # Проверка изменений
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Нет изменений для коммита"
        return 0
    fi
    
    # Показываем изменения
    print_info "Изменения для коммита:"
    git status --short
    
    # Подтверждение
    echo ""
    read -p "Продолжить с коммитом? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Коммит отменен"
        return 0
    fi
    
    # Создание коммита с conventional commits
    local full_message="$type: $message"
    
    git add .
    
    if git commit -m "$full_message"; then
        print_success "Коммит создан: $full_message"
        log "COMMIT" "$full_message"
    else
        print_error "Ошибка при создании коммита"
        return 1
    fi
}

# Пуш с проверками и опциями
cmd_push() {
    local branch="${2:-}"
    local force="${3:-}"
    
    print_header
    print_info "Отправка изменений"
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [ -z "$branch" ]; then
        branch=$(git branch --show-current)
    fi
    
    get_repo_info
    echo ""
    
    # Проверка наличия удаленного репозитория
    if ! git remote get-url origin > /dev/null 2>&1; then
        print_error "Удаленный репозиторий не настроен"
        echo "Используйте: $0 setup"
        return 1
    fi
    
    # Проверка новых коммитов
    print_info "Проверка состояния..."
    git fetch origin
    
    local ahead_behind=$(git rev-list --left-right --count HEAD...origin/$branch 2>/dev/null || echo "0 0")
    local ahead=$(echo $ahead_behind | awk '{print $1}')
    local behind=$(echo $ahead_behind | awk '{print $2}')
    
    if [ "$behind" -gt 0 ]; then
        print_warning "Удаленный репозиторий имеет новые коммиты ($behind)"
        read -p "Выполнить pull перед push? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cmd_pull "$branch"
        fi
    fi
    
    # Выполнение push
    print_info "Отправка изменений в $branch..."
    
    local push_cmd="git push origin $branch"
    if [ "$force" = "force" ]; then
        push_cmd="git push --force-with-lease origin $branch"
        print_warning "Используется принудительная отправка (force-with-lease)"
    fi
    
    if $push_cmd; then
        print_success "Изменения успешно отправлены в $branch"
        log "PUSH" "Успешный push в $branch"
    else
        print_error "Ошибка при отправке изменений"
        return 1
    fi
}

# Пул с опциями
cmd_pull() {
    local branch="${2:-}"
    
    print_header
    print_info "Получение изменений"
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [ -z "$branch" ]; then
        branch=$(git branch --show-current)
    fi
    
    get_repo_info
    echo ""
    
    print_info "Получение изменений из $branch..."
    
    if git pull origin "$branch"; then
        print_success "Изменения успешно получены"
        log "PULL" "Успешный pull из $branch"
    else
        print_error "Ошибка при получении изменений"
        return 1
    fi
}

# Расширенный лог
cmd_log() {
    local lines="${2:-10}"
    
    print_header
    print_info "История коммитов"
    
    if ! check_git_repo; then
        return 1
    fi
    
    get_repo_info
    echo ""
    
    print_info "Последние $lines коммитов:"
    git log --oneline --graph --decorate -n "$lines" --color=always
}

# Настройка репозитория
cmd_setup() {
    local username="${2:-}"
    local email="${3:-}"
    local repo_url="${4:-}"
    
    print_header
    print_info "Настройка Git репозитория"
    
    # Настройка пользователя
    if [ -n "$username" ]; then
        git config user.name "$username"
        print_success "Имя пользователя установлено: $username"
    fi
    
    if [ -n "$email" ]; then
        git config user.email "$email"
        print_success "Email установлен: $email"
    fi
    
    # Настройка удаленного репозитория
    if [ -n "$repo_url" ]; then
        if git remote get-url origin > /dev/null 2>&1; then
            git remote set-url origin "$repo_url"
            print_success "URL удаленного репозитория обновлен: $repo_url"
        else
            git remote add origin "$repo_url"
            print_success "Удаленный репозиторий добавлен: $repo_url"
        fi
    fi
    
    # Дополнительные настройки
    git config push.default simple
    git config pull.rebase false
    git config core.autocrlf input
    
    print_success "Базовая конфигурация Git завершена"
    
    # Показываем текущую конфигурацию
    echo ""
    print_info "Текущая конфигурация:"
    git config --list | grep -E "(user.name|user.email|remote.origin.url)" | while read -r line; do
        echo "  🔧 $line"
    done
}

# Создание новой ветки
cmd_branch() {
    local action="${2:-}"
    local branch_name="${3:-}"
    
    print_header
    
    if ! check_git_repo; then
        return 1
    fi
    
    case $action in
        "create")
            if [ -z "$branch_name" ]; then
                print_error "Укажите имя ветки"
                return 1
            fi
            
            if git checkout -b "$branch_name"; then
                print_success "Ветка создана и переключена: $branch_name"
                log "BRANCH" "Создана ветка: $branch_name"
            else
                print_error "Ошибка при создании ветки"
            fi
            ;;
        
        "list")
            print_info "Список веток:"
            git branch -a --color=always
            ;;
        
        "delete")
            if [ -z "$branch_name" ]; then
                print_error "Укажите имя ветки для удаления"
                return 1
            fi
            
            local current_branch=$(git branch --show-current)
            if [ "$branch_name" = "$current_branch" ]; then
                print_error "Нельзя удалить текущую ветку. Переключитесь на другую ветку."
                return 1
            fi
            
            read -p "Удалить ветку '$branch_name'? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if git branch -d "$branch_name"; then
                    print_success "Ветка удалена: $branch_name"
                else
                    print_error "Ошибка при удалении ветки"
                fi
            else
                print_info "Удаление отменено"
            fi
            ;;
        
        *)
            print_info "Текущие ветки:"
            git branch --color=always
            ;;
    esac
}

# Слияние веток
cmd_merge() {
    local source_branch="${2:-}"
    
    print_header
    print_info "Слияние веток"
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [ -z "$source_branch" ]; then
        print_error "Укажите ветку для слияния"
        return 1
    fi
    
    local current_branch=$(git branch --show-current)
    
    echo "  🌿 Текущая ветка: $current_branch"
    echo "  🔗 Ветка для слияния: $source_branch"
    echo ""
    
    # Проверка существования ветки
    if ! git show-ref --verify --quiet "refs/heads/$source_branch"; then
        print_error "Ветка '$source_branch' не существует"
        return 1
    fi
    
    read -p "Выполнить слияние $source_branch в $current_branch? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Слияние отменено"
        return 0
    fi
    
    if git merge "$source_branch"; then
        print_success "Слияние завершено успешно"
        log "MERGE" "Слияние $source_branch в $current_branch"
    else
        print_error "Конфликт при слиянии. Требуется ручное разрешение."
        return 1
    fi
}

# Просмотр различий
cmd_diff() {
    local file_path="${2:-}"
    
    print_header
    print_info "Просмотр различий"
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [ -n "$file_path" ]; then
        git diff "$file_path"
    else
        git diff
    fi
}

# Отмена изменений
cmd_undo() {
    local target="${2:-}"
    
    print_header
    
    if ! check_git_repo; then
        return 1
    fi
    
    case $target in
        "add")
            print_info "Отмена индексации всех файлов"
            git reset
            print_success "Индексация файлов отменена"
            ;;
        "commit")
            print_info "Отмена последнего коммита (сохраняя изменения)"
            git reset --soft HEAD~1
            print_success "Последний коммит отменен, изменения сохранены"
            ;;
        "hard")
            print_warning "Жесткая отмена всех изменений (потеря данных!)"
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git reset --hard HEAD
                print_success "Все изменения отменены"
            else
                print_info "Отмена операции"
            fi
            ;;
        *)
            print_info "Отмена изменений в неиндексированных файлах"
            git checkout -- .
            print_success "Изменения в файлах отменены"
            ;;
    esac
}

# Синхронизация (pull + push)
cmd_sync() {
    print_header
    print_info "Полная синхронизация репозитория"
    
    if ! check_git_repo; then
        return 1
    fi
    
    get_repo_info
    echo ""
    
    # Pull
    print_info "Получение изменений..."
    if cmd_pull; then
        # Push
        print_info "Отправка изменений..."
        if cmd_push; then
            print_success "Синхронизация завершена успешно"
            log "SYNC" "Полная синхронизация репозитория"
        else
            print_error "Ошибка при отправке изменений"
            return 1
        fi
    else
        print_error "Ошибка при получении изменений"
        return 1
    fi
}

# Информация о репозитории
cmd_info() {
    print_header
    print_info "Информация о репозитории"
    
    if ! check_git_repo; then
        return 1
    fi
    
    get_repo_info
    echo ""
    
    # Статистика
    print_info "Статистика репозитория:"
    local total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    local total_branches=$(git branch -r | wc -l | tr -d ' ')
    local total_tags=$(git tag | wc -l | tr -d ' ')
    local repo_size=$(du -sh .git 2>/dev/null | cut -f1 || echo "N/A")
    
    echo "  📊 Коммитов: $total_commits"
    echo "  🌿 Веток: $total_branches"
    echo "  🏷️  Тегов: $total_tags"
    echo "  💾 Размер: $repo_size"
    echo ""
    
    # Последние коммиты
    print_info "Последние коммиты:"
    git log --oneline -5 --color=always
}

# Инициализация нового репозитория
cmd_init() {
    local repo_name="${2:-}"
    
    print_header
    print_info "Инициализация нового Git репозитория"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Текущая директория уже является Git репозиторием"
        return 0
    fi
    
    if [ -n "$repo_name" ]; then
        mkdir -p "$repo_name"
        cd "$repo_name"
    fi
    
    git init
    print_success "Новый Git репозиторий инициализирован"
    
    # Создание README
    if [ ! -f "README.md" ]; then
        cat > README.md << EOF
# $(basename "$(pwd)")

Описание проекта.

## Установка

\`\`\`bash
# Инструкции по установке
\`\`\`

## Использование

Описание использования проекта.
EOF
        print_success "Создан файл README.md"
    fi
    
    log "INIT" "Инициализирован новый репозиторий"
}

# Помощь
cmd_help() {
    print_header
    echo -e "${CYAN}🔧 Продвинутый Git помощник - Справка${NC}"
    echo ""
    echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
    echo ""
    echo "Основные команды:"
    echo "  status                      - Статус репозитория"
    echo "  commit \"сообщение\" [тип]   - Умный коммит"
    echo "  push [ветка] [force]        - Отправка изменений"
    echo "  pull [ветка]                - Получение изменений"
    echo "  sync                        - Полная синхронизация"
    echo "  log [количество]            - История коммитов"
    echo ""
    echo "Управление ветками:"
    echo "  branch                      - Список веток"
    echo "  branch create <имя>         - Создать ветку"
    echo "  branch list                 - Все ветки"
    echo "  branch delete <имя>         - Удалить ветку"
    echo "  merge <ветка>               - Слияние веток"
    echo ""
    echo "Утилиты:"
    echo "  diff [файл]                 - Просмотр различий"
    echo "  undo [add|commit|hard]      - Отмена изменений"
    echo "  info                        - Информация о репо"
    echo "  init [имя]                  - Инициализация репо"
    echo "  setup [user] [email] [url]  - Настройка Git"
    echo "  help                        - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 status"
    echo "  $0 commit \"Добавлен новый скрипт\" feat"
    echo "  $0 push main"
    echo "  $0 branch create new-feature"
    echo "  $0 sync"
    echo "  $0 setup \"John Doe\" \"john@example.com\""
    echo ""
    echo -e "${YELLOW}💡 Типы коммитов: feat, fix, docs, style, refactor, test, chore${NC}"
}

# Основная функция
main() {
    check_git_installed
    
    case "${1:-help}" in
        "status") cmd_status "$@" ;;
        "commit") cmd_commit "$@" ;;
        "push") cmd_push "$@" ;;
        "pull") cmd_pull "$@" ;;
        "log") cmd_log "$@" ;;
        "setup") cmd_setup "$@" ;;
        "branch") cmd_branch "$@" ;;
        "merge") cmd_merge "$@" ;;
        "diff") cmd_diff "$@" ;;
        "undo") cmd_undo "$@" ;;
        "sync") cmd_sync "$@" ;;
        "info") cmd_info "$@" ;;
        "init") cmd_init "$@" ;;
        "help"|"--help"|"-h") cmd_help ;;
        *)
            print_error "Неизвестная команда: $1"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
