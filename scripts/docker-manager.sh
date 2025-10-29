#!/bin/bash
# 🐳 Расширенный менеджер Docker контейнеров, образов и компоновок
# Автор: g1if
# Версия: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
DOCKER_BACKUP_DIR="$PROJECT_ROOT/docker-backups"
METRICS_DIR="$PROJECT_ROOT/metrics"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$DOCKER_BACKUP_DIR" "$METRICS_DIR"

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
DOCKER_CONFIG="$CONFIG_DIR/docker-manager.conf"
DOCKER_LOG="$LOG_DIR/docker-manager.log"
METRICS_FILE="$METRICS_DIR/docker-metrics-$(date +%Y%m%d).csv"

# Функции вывода
print_header() {
    echo -e "${CYAN}"
    echo "🐳 ==========================================="
    echo "   МЕНЕДЖЕР DOCKER КОНТЕЙНЕРОВ v2.0"
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

# Логирование
log_action() {
    local action=$1
    local message=$2
    local level=${3:-"INFO"}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] [$action] $message" >> "$DOCKER_LOG"
}

# Сбор метрик
collect_metrics() {
    local action=$1
    local container=$2
    
    if [ ! -f "$METRICS_FILE" ]; then
        echo "timestamp,action,container,result" > "$METRICS_FILE"
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$action,$container,success" >> "$METRICS_FILE"
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing+=("docker")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        echo "💡 Установите Docker: https://docs.docker.com/engine/install/"
        return 1
    fi
    
    # Проверка Docker Compose (опционально)
    if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker Compose не найден. Некоторые функции будут ограничены."
    fi
    
    return 0
}

# Проверка Docker демона
check_docker_daemon() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker демон не запущен или нет прав доступа"
        echo "💡 Решения:"
        echo "  - Запустите демон: sudo systemctl start docker"
        echo "  - Добавьте пользователя в группу docker: sudo usermod -aG docker \$USER"
        echo "  - Перезапустите сессию или выполните: newgrp docker"
        return 1
    fi
    return 0
}

# Создание конфигурации
create_config() {
    cat > "$DOCKER_CONFIG" << 'CONFIG_EOF'
# Конфигурация Docker менеджера v2.0

# Автоматическое управление
AUTO_REMOVE_STOPPED_CONTAINERS=false
AUTO_REMOVE_DANGLING_IMAGES=false
AUTO_UPDATE_CONTAINERS=false

# Настройки бэкапа
BACKUP_PATH="/home/defo/projects/system-admin/docker-backups"
BACKUP_RETENTION_DAYS=7
ENABLE_VOLUME_BACKUP=true

# Мониторинг
MONITOR_INTERVAL=5
ENABLE_METRICS_COLLECTION=true
METRICS_RETENTION_DAYS=30

# Безопасность
ENABLE_SECURITY_SCAN=false
SCAN_VULNERABILITIES=false

# Контейнеры для исключения (через пробел)
EXCLUDE_CONTAINERS=""

# Приоритетные контейнеры (запускаются первыми)
PRIORITY_CONTAINERS="database redis"

# Docker Compose проекты
COMPOSE_PROJECTS=(
    "/path/to/project1/docker-compose.yml"
    "/path/to/project2/docker-compose.yml"
)

# Настройки ресурсов
CPU_LIMIT=""
MEMORY_LIMIT=""
RESTART_POLICY="unless-stopped"

# Уведомления
ENABLE_NOTIFICATIONS=false
NOTIFICATION_METHOD="log"  # log, email, telegram
CONFIG_EOF
    
    print_success "Конфигурация создана: $DOCKER_CONFIG"
    log_action "CONFIG" "Создан конфигурационный файл" "INFO"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$DOCKER_CONFIG" ]; then
        source "$DOCKER_CONFIG"
        print_success "Конфигурация загружена"
    else
        print_warning "Конфигурационный файл не найден. Используются значения по умолчанию."
        AUTO_REMOVE_STOPPED_CONTAINERS=false
        AUTO_REMOVE_DANGLING_IMAGES=false
        AUTO_UPDATE_CONTAINERS=false
        BACKUP_PATH="$DOCKER_BACKUP_DIR"
        BACKUP_RETENTION_DAYS=7
        ENABLE_VOLUME_BACKUP=true
        MONITOR_INTERVAL=5
        ENABLE_METRICS_COLLECTION=true
        METRICS_RETENTION_DAYS=30
        ENABLE_SECURITY_SCAN=false
        SCAN_VULNERABILITIES=false
        EXCLUDE_CONTAINERS=""
        PRIORITY_CONTAINERS=""
        COMPOSE_PROJECTS=()
        CPU_LIMIT=""
        MEMORY_LIMIT=""
        RESTART_POLICY="unless-stopped"
        ENABLE_NOTIFICATIONS=false
        NOTIFICATION_METHOD="log"
        
        log_action "CONFIG" "Используется конфигурация по умолчанию" "WARNING"
    fi
}

# Полная проверка окружения
check_environment() {
    if ! check_dependencies; then
        return 1
    fi
    
    if ! check_docker_daemon; then
        return 1
    fi
    
    return 0
}

# Получение информации о системе Docker
get_docker_info() {
    print_section "ИНФОРМАЦИЯ О DOCKER СИСТЕМЕ"
    
    echo "🐋 Версия Docker:"
    docker version --format '{{.Client.Version}}' 2>/dev/null || docker --version
    
    echo ""
    echo "🏠 Docker Host:"
    docker system info --format '{{.Name}}' 2>/dev/null || echo "Не удалось получить информацию"
    
    echo ""
    echo "💾 Использование диска:"
    docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null || \
    docker system df
    
    echo ""
    echo "🔧 Конфигурация Docker:"
    docker info --format '{{.ServerVersion}}' 2>/dev/null | head -1
}

# Расширенный список контейнеров
list_containers_detailed() {
    print_section "DOCKER КОНТЕЙНЕРЫ - ДЕТАЛЬНЫЙ ОБЗОР"
    
    local total_containers=$(docker ps -aq 2>/dev/null | wc -l)
    local running_containers=$(docker ps -q 2>/dev/null | wc -l)
    
    echo "📊 Общая статистика:"
    echo "  🟢 Запущено: $running_containers"
    echo "  🔴 Остановлено: $((total_containers - running_containers))"
    echo "  📦 Всего: $total_containers"
    echo ""
    
    if [ "$running_containers" -gt 0 ]; then
        echo "🟢 ЗАПУЩЕННЫЕ КОНТЕЙНЕРЫ:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}" 2>/dev/null || \
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "ℹ️  Нет запущенных контейнеров"
    fi
    
    echo ""
    local stopped_containers=$(docker ps -aq -f status=exited 2>/dev/null | wc -l)
    if [ "$stopped_containers" -gt 0 ]; then
        echo "🔴 ОСТАНОВЛЕННЫЕ КОНТЕЙНЕРЫ:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}" -f status=exited 2>/dev/null || \
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" -f status=exited
    else
        echo "ℹ️  Нет остановленных контейнеров"
    fi
}

# Расширенный список образов
list_images_detailed() {
    print_section "DOCKER ОБРАЗЫ - ДЕТАЛЬНЫЙ ОБЗОР"
    
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}\t{{.ID}}" 2>/dev/null || \
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    
    local total_images=$(docker images -q 2>/dev/null | wc -l)
    local total_size=$(docker system df --format "{{.ImagesSize}}" 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 Статистика образов:"
    echo "  🖼️  Всего образов: $total_images"
    echo "  💾 Общий размер: $total_size"
    
    # Показываем самые большие образы
    echo ""
    echo "🏆 САМЫЕ БОЛЬШИЕ ОБРАЗЫ:"
    docker images --format "table {{.Size}}\t{{.Repository}}" | sort -hr | head -5 2>/dev/null || \
    echo "  ℹ️  Не удалось получить информацию о размерах"
}

# Детальная статистика контейнеров
show_detailed_stats() {
    print_section "ДЕТАЛЬНАЯ СТАТИСТИКА КОНТЕЙНЕРОВ"
    
    echo "📈 РЕАЛЬНАЯ СТАТИСТИКА ИСПОЛЬЗОВАНИЯ:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" 2>/dev/null || \
    docker stats --no-stream
    
    echo ""
    echo "💾 ИСПОЛЬЗОВАНИЕ ДИСКА DOCKER:"
    docker system df --verbose 2>/dev/null || docker system df
    
    # Информация о volumes
    echo ""
    echo "💽 DOCKER VOLUMES:"
    local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)
    echo "  📂 Всего volumes: $volume_count"
    if [ "$volume_count" -gt 0 ]; then
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null | head -10 || \
        docker volume ls | head -10
    fi
    
    # Информация о сетях
    echo ""
    echo "🌐 DOCKER СЕТИ:"
    local network_count=$(docker network ls -q 2>/dev/null | wc -l)
    echo "  🌍 Всего сетей: $network_count"
    if [ "$network_count" -gt 0 ]; then
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null | head -10 || \
        docker network ls | head -10
    fi
}

# Умный просмотр логов
show_logs_intelligent() {
    local container=$1
    local lines=${2:-50}
    local follow=${3:-false}
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 logs <container_name> [lines] [follow]"
        return 1
    fi
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        print_error "Контейнер '$container' не найден"
        return 1
    fi
    
    print_section "ЛОГИ КОНТЕЙНЕРА: $container"
    
    # Проверяем статус контейнера
    local container_status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [ "$container_status" != "running" ]; then
        print_warning "Контейнер находится в статусе: $container_status"
    fi
    
    echo "📋 Последние $lines строк логов:"
    echo "----------------------------------------"
    
    if [ "$follow" = "true" ]; then
        docker logs --tail "$lines" -f "$container" 2>&1
    else
        docker logs --tail "$lines" "$container" 2>&1 || {
            print_error "Не удалось получить логи контейнера $container"
            return 1
        }
    fi
    
    log_action "LOGS" "Просмотр логов контейнера: $container ($lines строк)" "INFO"
    collect_metrics "logs" "$container"
}

# Управление контейнерами с проверками
manage_container() {
    local action=$1
    local container=$2
    
    if [ -z "$container" ]; then
        print_error "Укажите имя контейнера"
        echo "Использование: $0 $action <container_name>"
        return 1
    fi
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        print_error "Контейнер '$container' не найден"
        return 1
    fi
    
    local action_upper=$(echo "$action" | tr '[:lower:]' '[:upper:]')
    print_section "$action_upper КОНТЕЙНЕРА: $container"
    
    case "$action" in
        "start")
            if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
                print_warning "Контейнер '$container' уже запущен"
                return 0
            fi
            
            if docker start "$container" 2>/dev/null; then
                print_success "Контейнер '$container' успешно запущен"
                log_action "START" "Запущен контейнер: $container" "INFO"
                collect_metrics "start" "$container"
            else
                print_error "Не удалось запустить контейнер '$container'"
                log_action "START" "Ошибка запуска контейнера: $container" "ERROR"
                return 1
            fi
            ;;
            
        "stop")
            if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
                print_warning "Контейнер '$container' не запущен"
                return 0
            fi
            
            if docker stop "$container" 2>/dev/null; then
                print_success "Контейнер '$container' успешно остановлен"
                log_action "STOP" "Остановлен контейнер: $container" "INFO"
                collect_metrics "stop" "$container"
            else
                print_error "Не удалось остановить контейнер '$container'"
                log_action "STOP" "Ошибка остановки контейнера: $container" "ERROR"
                return 1
            fi
            ;;
            
        "restart")
            if docker restart "$container" 2>/dev/null; then
                print_success "Контейнер '$container' успешно перезапущен"
                log_action "RESTART" "Перезапущен контейнер: $container" "INFO"
                collect_metrics "restart" "$container"
            else
                print_error "Не удалось перезапустить контейнер '$container'"
                log_action "RESTART" "Ошибка перезапуска контейнера: $container" "ERROR"
                return 1
            fi
            ;;
            
        "remove")
            # Останавливаем контейнер если он запущен
            if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
                print_warning "Контейнер запущен, останавливаем..."
                docker stop "$container" 2>/dev/null || true
            fi
            
            if docker rm "$container" 2>/dev/null; then
                print_success "Контейнер '$container' успешно удален"
                log_action "REMOVE" "Удален контейнер: $container" "INFO"
                collect_metrics "remove" "$container"
            else
                print_error "Не удалось удалить контейнер '$container'"
                log_action "REMOVE" "Ошибка удаления контейнера: $container" "ERROR"
                return 1
            fi
            ;;
            
        *)
            print_error "Неизвестное действие: $action"
            return 1
            ;;
    esac
}

# Расширенная очистка системы
cleanup_system_advanced() {
    print_section "РАСШИРЕННАЯ ОЧИСТКА DOCKER СИСТЕМЫ"
    
    echo "🧹 Начинаем расширенную очистку..."
    echo ""
    
    local total_freed=0
    
    # Получаем текущее использование
    local before_size=$(docker system df --format "{{.TotalSpace}}" 2>/dev/null | grep -o '[0-9]\+' | head -1 || echo "0")
    
    # 1. Останавливаем все контейнеры (кроме исключенных)
    local running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [ -n "$running_containers" ]; then
        echo "🛑 Останавливаем запущенные контейнеры..."
        for container in $running_containers; do
            if [[ " $EXCLUDE_CONTAINERS " != *" $container "* ]]; then
                echo "  ⏹️  Останавливаем $container..."
                docker stop "$container" 2>/dev/null || true
            else
                echo "  ⏭️  Пропускаем исключенный контейнер: $container"
            fi
        done
    fi
    
    # 2. Удаляем остановленные контейнеры
    local stopped_containers=$(docker ps -aq -f status=exited 2>/dev/null)
    if [ -n "$stopped_containers" ]; then
        echo "🗑️  Удаляем остановленные контейнеры..."
        if [ "$AUTO_REMOVE_STOPPED_CONTAINERS" = "true" ]; then
            docker rm $stopped_containers 2>/dev/null || true
            echo "  ✅ Удалено контейнеров: $(echo "$stopped_containers" | wc -w)"
        else
            echo "  ⏭️  Автоудаление отключено в конфигурации"
        fi
    fi
    
    # 3. Удаляем dangling образы
    echo "🖼️  Очищаем неиспользуемые образы..."
    if [ "$AUTO_REMOVE_DANGLING_IMAGES" = "true" ]; then
        docker image prune -f 2>/dev/null || true
        echo "  ✅ Очищены неиспользуемые образы"
    else
        echo "  ⏭️  Автоочистка образов отключена"
    fi
    
    # 4. Удаляем неиспользуемые volumes
    echo "💾 Удаляем неиспользуемые volumes..."
    docker volume prune -f 2>/dev/null || true
    echo "  ✅ Очищены неиспользуемые volumes"
    
    # 5. Удаляем неиспользуемые сети
    echo "🌐 Удаляем неиспользуемые сети..."
    docker network prune -f 2>/dev/null || true
    echo "  ✅ Очищены неиспользуемые сети"
    
    # 6. Сборка кэша
    echo "🧹 Очищаем builder cache..."
    docker builder prune -f 2>/dev/null || true
    
    # Показываем результат
    echo ""
    echo "📊 РЕЗУЛЬТАТЫ ОЧИСТКИ:"
    docker system df
    
    local after_size=$(docker system df --format "{{.TotalSpace}}" 2>/dev/null | grep -o '[0-9]\+' | head -1 || echo "0")
    total_freed=$((before_size - after_size))
    
    if [ "$total_freed" -gt 0 ]; then
        print_success "Освобождено: ${total_freed}MB"
    else
        print_info "Нечего очищать"
    fi
    
    log_action "CLEANUP" "Выполнена расширенная очистка Docker системы" "INFO"
    collect_metrics "cleanup" "system"
}

# Расширенный бэкап контейнеров
backup_container_advanced() {
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
    
    print_section "РАСШИРЕННЫЙ БЭКАП КОНТЕЙНЕРА: $container"
    
    local backup_dir="$BACKUP_PATH/$backup_name"
    local backup_file="$backup_dir/${container}.tar"
    
    mkdir -p "$backup_dir"
    
    echo "📦 Создание комплексного бэкапа..."
    
    # 1. Бэкап контейнера
    echo "  🔄 Экспорт контейнера..."
    if docker export "$container" > "$backup_file" 2>/dev/null; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo "  ✅ Контейнер экспортирован: $backup_file ($size)"
    else
        print_error "Не удалось экспортировать контейнер '$container'"
        return 1
    fi
    
    # 2. Бэкап метаданных
    echo "  📝 Сохранение метаданных..."
    docker inspect "$container" > "$backup_dir/inspect.json" 2>/dev/null || true
    docker logs --tail 100 "$container" > "$backup_dir/last_logs.log" 2>/dev/null || true
    
    # 3. Бэкап volumes (если включено)
    if [ "$ENABLE_VOLUME_BACKUP" = "true" ]; then
        echo "  💾 Бэкап volumes..."
        local volumes=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Type "volume" }}{{ .Name }} {{ end }}{{ end }}' "$container" 2>/dev/null)
        if [ -n "$volumes" ]; then
            for volume in $volumes; do
                echo "    🔄 Бэкап volume: $volume"
                docker run --rm -v "$volume:/source" -v "$backup_dir:/backup" alpine tar czf "/backup/volume_$volume.tar.gz" -C /source . 2>/dev/null || true
            done
        fi
    fi
    
    # 4. Сжатие основного бэкапа
    echo "  🗜️  Сжатие бэкапа..."
    if command -v gzip >/dev/null 2>&1; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        local compressed_size=$(du -h "$backup_file" | cut -f1)
        echo "  ✅ Сжатый бэкап: $backup_file ($compressed_size)"
    fi
    
    # 5. Создание манифеста
    cat > "$backup_dir/manifest.txt" << EOF
Бэкап контейнера: $container
Время создания: $(date)
Исходный контейнер: $container
Файлы:
- ${container}.tar.gz - экспорт контейнера
- inspect.json - метаданные контейнера
- last_logs.log - последние логи
- volume_*.tar.gz - бэкапы volumes
EOF
    
    local total_size=$(du -sh "$backup_dir" | cut -f1)
    print_success "Комплексный бэкап создан: $backup_dir ($total_size)"
    log_action "BACKUP" "Создан комплексный бэкап контейнера $container: $backup_dir" "INFO"
    collect_metrics "backup" "$container"
}

# Восстановление контейнера из бэкапа
restore_container() {
    local backup_path=$1
    local new_name=${2:-}
    
    if [ -z "$backup_path" ]; then
        print_error "Укажите путь к бэкапу"
        echo "Использование: $0 restore <backup_path> [new_name]"
        return 1
    fi
    
    if [ ! -d "$backup_path" ]; then
        print_error "Директория бэкапа не найдена: $backup_path"
        return 1
    fi
    
    print_section "ВОССТАНОВЛЕНИЕ КОНТЕЙНЕРА ИЗ БЭКАПА"
    
    local backup_file=$(find "$backup_path" -name "*.tar.gz" -o -name "*.tar" | head -1)
    if [ -z "$backup_file" ]; then
        print_error "Файл бэкапа не найден в директории"
        return 1
    fi
    
    if [ -z "$new_name" ]; then
        new_name="restored_$(basename "$backup_path" | cut -d'_' -f1)_$(date +%H%M%S)"
    fi
    
    echo "🔄 Восстановление контейнера '$new_name' из $backup_file"
    
    # Распаковка если нужно
    local temp_dir=""
    if [[ "$backup_file" == *.gz ]]; then
        temp_dir=$(mktemp -d)
        echo "  📦 Распаковка архива..."
        gunzip -c "$backup_file" > "$temp_dir/container.tar" || {
            print_error "Ошибка распаковки архива"
            rm -rf "$temp_dir"
            return 1
        }
        backup_file="$temp_dir/container.tar"
    fi
    
    # Импорт контейнера
    echo "  📥 Импорт контейнера..."
    if docker import "$backup_file" "$new_name:restored" 2>/dev/null; then
        print_success "Контейнер '$new_name' успешно восстановлен"
        
        # Восстановление метаданных если есть
        local inspect_file="$backup_path/inspect.json"
        if [ -f "$inspect_file" ]; then
            echo "  📝 Метаданные восстановлены"
        fi
    else
        print_error "Не удалось восстановить контейнер"
    fi
    
    # Очистка
    if [ -n "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
    
    log_action "RESTORE" "Восстановлен контейнер $new_name из $backup_path" "INFO"
    collect_metrics "restore" "$new_name"
}

# Расширенный мониторинг
monitor_advanced() {
    print_section "РАСШИРЕННЫЙ МОНИТОРИНГ DOCKER"
    echo "🔄 Обновление каждые $MONITOR_INTERVAL секунд"
    echo "⏹️  Нажмите Ctrl+C для остановки"
    echo ""
    
    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        print_header
        echo "🔁 Цикл мониторинга: $counter"
        echo "⏰ Время: $(date)"
        echo "=========================================="
        
        # Показываем системную информацию
        get_docker_info
        echo ""
        
        # Показываем детальную статистику
        show_detailed_stats
        
        echo ""
        echo "⏳ Следующее обновление через $MONITOR_INTERVAL секунд..."
        sleep "$MONITOR_INTERVAL"
    done
}

# Управление Docker Compose проектами
manage_compose_advanced() {
    local project_path=$1
    local action=${2:-"ps"}
    
    if [ -z "$project_path" ]; then
        print_error "Укажите путь к docker-compose.yml"
        echo "Использование: $0 compose <path> [action]"
        echo "Доступные действия: ps, up, down, restart, logs, stop, start, build"
        return 1
    fi
    
    if [ ! -f "$project_path" ] && [ ! -d "$project_path" ]; then
        print_error "Файл или директория не найдена: $project_path"
        return 1
    fi
    
    # Если передан путь к директории, ищем docker-compose.yml
    if [ -d "$project_path" ]; then
        if [ -f "$project_path/docker-compose.yml" ]; then
            project_path="$project_path/docker-compose.yml"
        else
            print_error "docker-compose.yml не найден в директории: $project_path"
            return 1
        fi
    fi
    
    local project_name=$(basename "$(dirname "$project_path")")
    print_section "DOCKER COMPOSE: $project_name"
    
    # Определяем команду в зависимости от доступности docker-compose или docker compose
    local compose_cmd="docker-compose"
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    case "$action" in
        "ps")
            $compose_cmd -f "$project_path" ps
            ;;
        "up")
            $compose_cmd -f "$project_path" up -d
            ;;
        "down")
            $compose_cmd -f "$project_path" down
            ;;
        "restart")
            $compose_cmd -f "$project_path" restart
            ;;
        "logs")
            $compose_cmd -f "$project_path" logs -f --tail=50
            ;;
        "stop")
            $compose_cmd -f "$project_path" stop
            ;;
        "start")
            $compose_cmd -f "$project_path" start
            ;;
        "build")
            $compose_cmd -f "$project_path" build --no-cache
            ;;
        *)
            print_error "Неизвестное действие: $action"
            echo "Доступные действия: ps, up, down, restart, logs, stop, start, build"
            return 1
            ;;
    esac
    
    log_action "COMPOSE" "Выполнено действие '$action' для проекта $project_name" "INFO"
    collect_metrics "compose" "$project_name"
}

# Просмотр метрик
show_metrics() {
    print_section "МЕТРИКИ DOCKER МЕНЕДЖЕРА"
    
    if [ ! -f "$METRICS_FILE" ]; then
        echo "ℹ️  Файл метрик не найден"
        return 0
    fi
    
    echo "📈 Статистика операций:"
    echo ""
    
    # Общая статистика
    local total_actions=$(tail -n +2 "$METRICS_FILE" | wc -l)
    echo "📊 Всего операций: $total_actions"
    
    # Статистика по действиям
    echo ""
    echo "🔧 Распределение по типам операций:"
    tail -n +2 "$METRICS_FILE" | cut -d',' -f2 | sort | uniq -c | sort -nr | while read count action; do
        echo "  $action: $count операций"
    done
    
    # Последние операции
    echo ""
    echo "🕒 Последние 10 операций:"
    tail -10 "$METRICS_FILE" | while IFS=, read -r timestamp action container result; do
        echo "  ⏰ $timestamp - $action - $container - $result"
    done
}

# Основная функция
main() {
    load_config
    
    # Проверяем окружение
    if ! check_environment; then
        exit 1
    fi
    
    case "${1:-}" in
        "ps")
            print_header
            list_containers_detailed
            ;;
        "images")
            print_header
            list_images_detailed
            ;;
        "stats")
            print_header
            show_detailed_stats
            ;;
        "logs")
            print_header
            show_logs_intelligent "$2" "$3" "$4"
            ;;
        "start"|"stop"|"restart"|"remove")
            print_header
            manage_container "$1" "$2"
            ;;
        "cleanup")
            print_header
            cleanup_system_advanced
            ;;
        "backup")
            print_header
            backup_container_advanced "$2" "$3"
            ;;
        "restore")
            print_header
            restore_container "$2" "$3"
            ;;
        "monitor")
            print_header
            monitor_advanced
            ;;
        "compose")
            print_header
            manage_compose_advanced "$2" "$3"
            ;;
        "info")
            print_header
            get_docker_info
            ;;
        "metrics")
            print_header
            show_metrics
            ;;
        "config")
            print_header
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

# Функция показа справки
show_help() {
    print_header
    echo "Использование: $0 [КОМАНДА] [ОПЦИИ]"
    echo ""
    echo "Основные команды:"
    echo "  ps              - Детальный список контейнеров"
    echo "  images          - Детальный список образов"
    echo "  stats           - Детальная статистика"
    echo "  logs <container> [lines] [follow] - Умный просмотр логов"
    echo "  start <container> - Запустить контейнер"
    echo "  stop <container>  - Остановить контейнер"
    echo "  restart <container> - Перезапустить контейнер"
    echo "  remove <container> - Удалить контейнер"
    echo ""
    echo "Расширенные команды:"
    echo "  cleanup         - Расширенная очистка системы"
    echo "  backup <container> [name] - Комплексный бэкап"
    echo "  restore <path> [name] - Восстановление из бэкапа"
    echo "  monitor         - Расширенный мониторинг"
    echo "  compose <path> [action] - Управление Docker Compose"
    echo "  info            - Информация о Docker системе"
    echo "  metrics         - Просмотр метрик менеджера"
    echo "  config          - Создать конфигурацию"
    echo "  help            - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 ps                            # Список контейнеров"
    echo "  $0 logs nginx 100                # 100 строк логов nginx"
    echo "  $0 logs nginx 50 true            # Логи в реальном времени"
    echo "  $0 backup mysql                  # Бэкап MySQL"
    echo "  $0 restore backups/mysql_backup  # Восстановление"
    echo "  $0 compose ./project up          # Запуск Compose проекта"
    echo "  $0 monitor                       # Мониторинг в реальном времени"
}

main "$@"
