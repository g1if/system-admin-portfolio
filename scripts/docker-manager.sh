#!/bin/bash
# 🐳 Менеджер Docker контейнеров и образов
# Автор: g1if

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
DOCKER_DIR="$PROJECT_ROOT/docker-backups"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$DOCKER_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Конфигурация
DOCKER_CONFIG="$CONFIG_DIR/docker-manager.conf"
DOCKER_LOG="$LOG_DIR/docker-manager.log"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🐳 ==========================================="
    echo "   МЕНЕДЖЕР DOCKER КОНТЕЙНЕРОВ v1.0"
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
    echo "Использование: $0 [КОМАНДА] [ОПЦИИ]"
    echo ""
    echo "Команды:"
    echo "  ps         - Список контейнеров"
    echo "  images     - Список образов"
    echo "  stats      - Статистика контейнеров"
    echo "  logs       - Логи контейнера"
    echo "  start      - Запустить контейнер"
    echo "  stop       - Остановить контейнер"
    echo "  restart    - Перезапустить контейнер"
    echo "  remove     - Удалить контейнер"
    echo "  cleanup    - Очистка системы"
    echo "  backup     - Бэкап контейнера"
    echo "  monitor    - Мониторинг в реальном времени"
    echo "  compose    - Управление Docker Compose"
    echo "  config     - Создать конфигурацию"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 ps                      # Список контейнеров"
    echo "  $0 logs nginx              # Логи контейнера nginx"
    echo "  $0 stop container_name     # Остановить контейнер"
    echo "  $0 cleanup                 # Очистка системы"
    echo "  $0 backup nginx            # Бэкап контейнера nginx"
    echo "  $0 monitor                 # Мониторинг в реальном времени"
}

# Создание конфигурации
create_config() {
    cat > "$DOCKER_CONFIG" << 'EOF'
# Конфигурация Docker менеджера

# Автоматически удалять контейнеры при очистке?
AUTO_REMOVE_CONTAINERS=false

# Автоматически удалять образы при очистке?
AUTO_REMOVE_IMAGES=false

# Путь для бэкапов
BACKUP_PATH="/home/defo/projects/system-admin/docker-backups"

# Мониторинг - интервал обновления (секунды)
MONITOR_INTERVAL=5

# Контейнеры для исключения из операций (через пробел)
EXCLUDE_CONTAINERS=""

# Docker Compose проекты для мониторинга
COMPOSE_PROJECTS=(
    "/path/to/your/docker-compose.yml"
)
EOF
    print_success "Конфигурация создана: $DOCKER_CONFIG"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$DOCKER_CONFIG" ]; then
        source "$DOCKER_CONFIG"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        AUTO_REMOVE_CONTAINERS=false
        AUTO_REMOVE_IMAGES=false
        BACKUP_PATH="$DOCKER_DIR"
        MONITOR_INTERVAL=5
        EXCLUDE_CONTAINERS=""
        COMPOSE_PROJECTS=()
    fi
}

# Логирование
log_action() {
    local action=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$action] $message" >> "$DOCKER_LOG"
    echo "  📝 Лог: $message"
}

# Проверка установки Docker
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker не установлен или не запущен"
        echo "Установите Docker: https://docs.docker.com/engine/install/"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker демон не запущен или нет прав доступа"
        echo "Добавьте пользователя в группу docker: sudo usermod -aG docker \$USER"
        echo "И перезапустите сессию или запустите демон: sudo systemctl start docker"
        return 1
    fi
    
    return 0
}

# Список контейнеров
list_containers() {
    print_section "DOCKER КОНТЕЙНЕРЫ"
    
    echo "🟢 Запущенные контейнеры:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    
    echo ""
    echo "🔴 Остановленные контейнеры:"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" --filter "status=exited" 2>/dev/null || \
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" --filter "status=exited"
    
    local total=$(docker ps -aq | wc -l 2>/dev/null || echo "0")
    local running=$(docker ps -q | wc -l 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 Статистика:"
    echo "  Всего контейнеров: $total"
    echo "  Запущено: $running"
    echo "  Остановлено: $((total - running))"
}

# Список образов
list_images() {
    print_section "DOCKER ОБРАЗЫ"
    
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null || \
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    
    local total=$(docker images -q | wc -l 2>/dev/null || echo "0")
    local size=$(docker system df --format "{{.ImagesSize}}" 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 Статистика образов:"
    echo "  Всего образов: $total"
    echo "  Общий размер: $size"
}

# Статистика контейнеров
show_stats() {
    print_section "СТАТИСТИКА КОНТЕЙНЕРОВ"
    
    echo "📈 Реальная статистика использования:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || \
    docker stats --no-stream
    
    echo ""
    echo "💾 Использование диска Docker:"
    docker system df --verbose 2>/dev/null || docker system df
}

# Просмотр логов контейнера
show_logs() {
    local container=$1
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 logs <container_name>"
        return 1
    fi
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        print_error "Контейнер '$container' не найден"
        return 1
    fi
    
    print_section "ЛОГИ КОНТЕЙНЕРА: $container"
    
    # Показываем последние 50 строк логов
    docker logs --tail 50 "$container" 2>&1 || {
        print_error "Не удалось получить логи контейнера $container"
        return 1
    }
}

# Запуск контейнера
start_container() {
    local container=$1
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 start <container_name>"
        return 1
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
        print_warning "Контейнер '$container' уже запущен"
        return 0
    fi
    
    print_section "ЗАПУСК КОНТЕЙНЕРА: $container"
    
    if docker start "$container" 2>/dev/null; then
        print_success "Контейнер '$container' успешно запущен"
        log_action "START" "Запущен контейнер: $container"
    else
        print_error "Не удалось запустить контейнер '$container'"
        return 1
    fi
}

# Остановка контейнера
stop_container() {
    local container=$1
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 stop <container_name>"
        return 1
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
        print_warning "Контейнер '$container' не запущен"
        return 0
    fi
    
    print_section "ОСТАНОВКА КОНТЕЙНЕРА: $container"
    
    if docker stop "$container" 2>/dev/null; then
        print_success "Контейнер '$container' успешно остановлен"
        log_action "STOP" "Остановлен контейнер: $container"
    else
        print_error "Не удалось остановить контейнер '$container'"
        return 1
    fi
}

# Перезапуск контейнера
restart_container() {
    local container=$1
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 restart <container_name>"
        return 1
    fi
    
    print_section "ПЕРЕЗАПУСК КОНТЕЙНЕРА: $container"
    
    if docker restart "$container" 2>/dev/null; then
        print_success "Контейнер '$container' успешно перезапущен"
        log_action "RESTART" "Перезапущен контейнер: $container"
    else
        print_error "Не удалось перезапустить контейнер '$container'"
        return 1
    fi
}

# Удаление контейнера
remove_container() {
    local container=$1
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 remove <container_name>"
        return 1
    fi
    
    print_section "УДАЛЕНИЕ КОНТЕЙНЕРА: $container"
    
    # Останавливаем контейнер если он запущен
    if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
        print_warning "Контейнер запущен, останавливаем..."
        docker stop "$container" 2>/dev/null || true
    fi
    
    if docker rm "$container" 2>/dev/null; then
        print_success "Контейнер '$container' успешно удален"
        log_action "REMOVE" "Удален контейнер: $container"
    else
        print_error "Не удалось удалить контейнер '$container'"
        return 1
    fi
}

# Очистка системы Docker
cleanup_system() {
    print_section "ОЧИСТКА DOCKER СИСТЕМЫ"
    
    echo "🧹 Начинаем очистку..."
    
    # Останавливаем все контейнеры
    local running_containers=$(docker ps -q 2>/dev/null | wc -l)
    if [ "$running_containers" -gt 0 ]; then
        echo "🛑 Останавливаем запущенные контейнеры..."
        docker stop $(docker ps -q) 2>/dev/null || true
    fi
    
    # Удаляем остановленные контейнеры
    local stopped_containers=$(docker ps -aq -f status=exited 2>/dev/null | wc -l)
    if [ "$stopped_containers" -gt 0 ]; then
        echo "🗑️ Удаляем остановленные контейнеры..."
        docker rm $(docker ps -aq -f status=exited) 2>/dev/null || true
    fi
    
    # Удаляем dangling образы
    echo "🖼️ Удаляем неиспользуемые образы..."
    docker image prune -f 2>/dev/null || true
    
    # Удаляем неиспользуемые volumes
    echo "💾 Удаляем неиспользуемые volumes..."
    docker volume prune -f 2>/dev/null || true
    
    # Удаляем неиспользуемые сети
    echo "🌐 Удаляем неиспользуемые сети..."
    docker network prune -f 2>/dev/null || true
    
    # Показываем результат
    echo ""
    echo "📊 Результаты очистки:"
    docker system df
    
    log_action "CLEANUP" "Выполнена очистка Docker системы"
}

# Бэкап контейнера
backup_container() {
    local container=$1
    local backup_name=${2:-"${container}_backup_$(date +%Y%m%d_%H%M%S)"}
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 backup <container_name> [backup_name]"
        return 1
    fi
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        print_error "Контейнер '$container' не найден"
        return 1
    fi
    
    print_section "БЭКАП КОНТЕЙНЕРА: $container"
    
    local backup_file="$BACKUP_PATH/${backup_name}.tar"
    
    echo "📦 Создание бэкапа контейнера..."
    
    # Создаем бэкап
    if docker export "$container" > "$backup_file" 2>/dev/null; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Бэкап создан: $backup_file ($size)"
        log_action "BACKUP" "Создан бэкап контейнера $container: $backup_file"
        
        # Сжимаем бэкап
        echo "🗜️ Сжимаем бэкап..."
        if command -v gzip >/dev/null 2>&1; then
            gzip "$backup_file"
            backup_file="${backup_file}.gz"
            local compressed_size=$(du -h "$backup_file" | cut -f1)
            echo "✅ Сжатый бэкап: $backup_file ($compressed_size)"
        fi
    else
        print_error "Не удалось создать бэкап контейнера '$container'"
        return 1
    fi
}

# Мониторинг в реальном времени
monitor_containers() {
    print_section "МОНИТОРИНГ DOCKER В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "🔄 Обновление каждые $MONITOR_INTERVAL секунд"
    echo "⏹️ Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "🔁 Цикл мониторинга: $counter"
        echo "=========================================="
        
        # Показываем статистику
        show_stats
        
        echo ""
        echo "⏳ Следующее обновление через $MONITOR_INTERVAL секунд..."
        sleep "$MONITOR_INTERVAL"
    done
}

# Управление Docker Compose
manage_compose() {
    local project_path=$1
    local action=${2:-"ps"}
    
    if [ -z "$project_path" ]; then
        print_error "Укажите путь к docker-compose.yml"
        echo "Использование: $0 compose <path> [action]"
        echo "Доступные действия: ps, up, down, restart, logs"
        return 1
    fi
    
    if [ ! -f "$project_path" ]; then
        print_error "Файл не найден: $project_path"
        return 1
    fi
    
    print_section "DOCKER COMPOSE: $(basename $(dirname "$project_path"))"
    
    case "$action" in
        "ps")
            docker-compose -f "$project_path" ps
            ;;
        "up")
            docker-compose -f "$project_path" up -d
            ;;
        "down")
            docker-compose -f "$project_path" down
            ;;
        "restart")
            docker-compose -f "$project_path" restart
            ;;
        "logs")
            docker-compose -f "$project_path" logs -f
            ;;
        *)
            print_error "Неизвестное действие: $action"
            echo "Доступные действия: ps, up, down, restart, logs"
            return 1
            ;;
    esac
}

# Основная функция
main() {
    load_config
    
    # Проверяем Docker
    if ! check_docker; then
        exit 1
    fi
    
    case "${1:-}" in
        "ps")
            print_header
            list_containers
            ;;
        "images")
            print_header
            list_images
            ;;
        "stats")
            print_header
            show_stats
            ;;
        "logs")
            print_header
            show_logs "$2"
            ;;
        "start")
            print_header
            start_container "$2"
            ;;
        "stop")
            print_header
            stop_container "$2"
            ;;
        "restart")
            print_header
            restart_container "$2"
            ;;
        "remove")
            print_header
            remove_container "$2"
            ;;
        "cleanup")
            print_header
            cleanup_system
            ;;
        "backup")
            print_header
            backup_container "$2" "$3"
            ;;
        "monitor")
            print_header
            monitor_containers
            ;;
        "compose")
            print_header
            manage_compose "$2" "$3"
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

main "$@"
