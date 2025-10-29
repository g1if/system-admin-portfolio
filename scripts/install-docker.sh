#!/bin/bash
# 🔧 Продвинутая автоматическая установка и настройка Docker
# Автор: g1if
# Версия: 2.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/configs"
LOG_FILE="$LOG_DIR/docker-install.log"

mkdir -p "$LOG_DIR" "$CONFIG_DIR"

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
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO" "$1"
}

print_header() {
    echo -e "${CYAN}"
    echo "🐳 ==========================================="
    echo "   ПРОДВИНУТАЯ УСТАНОВКА DOCKER v2.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

# Проверка зависимостей
check_dependencies() {
    local missing=()
    
    for cmd in curl gpg apt-get systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют обязательные утилиты: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
    
    print_info "Обнаружен дистрибутив: $DISTRO $VERSION ($CODENAME)"
}

# Проверка поддержки дистрибутива
check_distro_support() {
    case $DISTRO in
        ubuntu|debian)
            print_success "Дистрибутив поддерживается"
            ;;
        centos|rhel|fedora)
            print_warning "Дистрибутив требует ручной установки. См. документацию Docker."
            exit 1
            ;;
        *)
            print_error "Дистрибутив $DISTRO не поддерживается автоматической установкой"
            exit 1
            ;;
    esac
}

# Проверка архитектуры
check_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            print_success "Архитектура x86_64 поддерживается"
            ;;
        aarch64|arm64)
            print_success "Архитектура ARM64 поддерживается"
            ;;
        *)
            print_error "Архитектура $arch не поддерживается"
            exit 1
            ;;
    esac
}

# Проверка текущей установки Docker
check_docker() {
    print_info "Проверка текущей установки Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        print_success "Docker уже установлен: $DOCKER_VERSION"
        
        if docker info >/dev/null 2>&1; then
            print_success "Docker демон работает"
            return 0
        else
            print_warning "Docker установлен, но демон не запущен"
            return 1
        fi
    else
        print_info "Docker не установлен"
        return 1
    fi
}

# Проверка старых версий Docker
check_old_docker() {
    print_info "Проверка старых версий Docker..."
    
    local old_packages=("docker" "docker-engine" "docker.io" "containerd" "runc")
    local found_old=0
    
    for pkg in "${old_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg"; then
            print_warning "Найдена старая версия: $pkg"
            found_old=1
        fi
    done
    
    if [ $found_old -eq 1 ]; then
        print_warning "Рекомендуется удалить старые версии перед установкой"
        read -p "Удалить старые версии Docker? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_old_docker
        fi
    fi
}

# Удаление старых версий Docker
remove_old_docker() {
    print_info "Удаление старых версий Docker..."
    
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    
    # Удаление конфигурационных файлов
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    
    print_success "Старые версии Docker удалены"
}

# Обновление системы
update_system() {
    print_info "Обновление системы..."
    
    sudo apt-get update
    sudo apt-get upgrade -y
    
    print_success "Система обновлена"
}

# Установка зависимостей
install_dependencies() {
    print_info "Установка зависимостей..."
    
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    print_success "Зависимости установлены"
}

# Добавление GPG ключа Docker
add_docker_gpg() {
    print_info "Добавление GPG ключа Docker..."
    
    # Создаем директорию для ключей
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Скачиваем и добавляем ключ
    curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Устанавливаем правильные права
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    print_success "GPG ключ Docker добавлен"
}

# Добавление репозитория Docker
add_docker_repo() {
    print_info "Добавление репозитория Docker..."
    
    local arch=$(dpkg --print-architecture)
    local repo_url="deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $CODENAME stable"
    
    echo "$repo_url" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Обновляем пакеты с новым репозиторием
    sudo apt-get update
    
    print_success "Репозиторий Docker добавлен"
}

# Установка Docker
install_docker_packages() {
    print_info "Установка Docker..."
    
    # Устанавливаем последние версии пакетов
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    print_success "Docker установлен"
}

# Настройка Docker демона
configure_docker_daemon() {
    print_info "Настройка Docker демона..."
    
    # Создаем конфигурацию демона
    sudo mkdir -p /etc/docker
    
    cat << EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "metrics-addr": "127.0.0.1:9323"
}
EOF
    
    print_success "Конфигурация Docker демона создана"
}

# Запуск и включение Docker
start_docker_service() {
    print_info "Запуск Docker службы..."
    
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Ждем запуска службы
    sleep 3
    
    if sudo systemctl is-active --quiet docker; then
        print_success "Docker служба запущена и включена"
    else
        print_error "Не удалось запустить Docker службу"
        exit 1
    fi
}

# Добавление пользователя в группу docker
add_user_to_docker_group() {
    print_info "Добавление пользователя в группу docker..."
    
    if ! groups $USER | grep -q '\bdocker\b'; then
        sudo usermod -aG docker $USER
        print_success "Пользователь $USER добавлен в группу docker"
    else
        print_info "Пользователь уже в группе docker"
    fi
}

# Установка Docker Compose (отдельная утилита)
install_docker_compose() {
    print_info "Установка Docker Compose..."
    
    local compose_version="v2.24.5"
    local arch=$(uname -m)
    
    case $arch in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) arch="x86_64" ;;
    esac
    
    # Скачиваем бинарник
    sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-linux-$arch" \
        -o /usr/local/bin/docker-compose
    
    # Даем права на выполнение
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Создаем симлинк для обратной совместимости
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose $compose_version установлен"
}

# Проверка установки
verify_installation() {
    print_info "Проверка установки..."
    
    # Проверяем версию Docker
    if docker --version > /dev/null 2>&1; then
        local version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        print_success "Docker версия: $version"
    else
        print_error "Docker не работает"
        exit 1
    fi
    
    # Проверяем работу демона
    if docker info > /dev/null 2>&1; then
        print_success "Docker демон работает корректно"
    else
        print_error "Проблема с Docker демоном"
        exit 1
    fi
    
    # Проверяем Docker Compose
    if docker-compose --version > /dev/null 2>&1; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | sed 's/,//')
        print_success "Docker Compose версия: $compose_version"
    else
        print_warning "Docker Compose не работает"
    fi
    
    # Тестовый запуск контейнера
    print_info "Запуск тестового контейнера..."
    if sudo docker run --rm hello-world | grep -q "Hello from Docker"; then
        print_success "Тестовый контейнер выполнен успешно"
    else
        print_warning "Тестовый контейнер не выполнился"
    fi
}

# Создание алиасов и полезных команд
create_aliases() {
    print_info "Создание полезных алиасов..."
    
    local aliases_file="$HOME/.docker_aliases"
    
    cat > "$aliases_file" << 'EOF'
# Docker Aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dstop='docker stop'
alias dstart='docker start'
alias drestart='docker restart'
alias dlogs='docker logs'
alias dexec='docker exec -it'
alias dcomp='docker-compose'
alias dcompose='docker-compose'

# Docker Cleanup
alias dclean='docker system prune -f'
alias dcleani='docker images -q | xargs docker rmi -f 2>/dev/null || true'
alias dcleanc='docker ps -aq | xargs docker rm -f 2>/dev/null || true'

# Docker Stats
alias dstats='docker stats --no-stream'
alias dtop='docker stats'

# Docker Network
alias dnet='docker network ls'
alias dvol='docker volume ls'

EOF
    
    # Добавляем в .bashrc если еще нет
    if ! grep -q "docker_aliases" "$HOME/.bashrc"; then
        echo "source $HOME/.docker_aliases" >> "$HOME/.bashrc"
    fi
    
    print_success "Алиасы созданы: $aliases_file"
}

# Показать информацию после установки
show_post_install_info() {
    print_header
    echo -e "${GREEN}🎉 Установка Docker завершена успешно!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Важные следующие шаги:${NC}"
    echo "  1. Выполните команду: ${CYAN}newgrp docker${NC}"
    echo "  2. Или перезайдите в систему для применения изменений группы"
    echo ""
    echo -e "${YELLOW}🔧 Проверка установки:${NC}"
    echo "  ${CYAN}docker --version${NC}"
    echo "  ${CYAN}docker ps${NC}"
    echo "  ${CYAN}docker-compose --version${NC}"
    echo ""
    echo -e "${YELLOW}🐳 Полезные команды:${NC}"
    echo "  ${CYAN}source ~/.docker_aliases${NC} - загрузить алиасы"
    echo "  ${CYAN}dps${NC} - список контейнеров"
    echo "  ${CYAN}dcomp up -d${NC} - запуск docker-compose"
    echo ""
    echo -e "${YELLOW}📚 Документация:${NC}"
    echo "  https://docs.docker.com/"
    echo "  https://docs.docker.com/compose/"
    echo ""
    echo -e "${CYAN}📝 Логи установки: $LOG_FILE${NC}"
}

# Основная функция установки
install_docker() {
    print_header
    
    # Проверка прав
    if [ "$EUID" -eq 0 ]; then
        print_error "Не запускайте скрипт с sudo. Скрипт сам запросит права когда нужно."
        exit 1
    fi
    
    log "INFO" "Начало установки Docker"
    
    # Проверка зависимостей
    if ! check_dependencies; then
        exit 1
    fi
    
    # Определение дистрибутива
    detect_distro
    check_distro_support
    check_architecture
    
    # Проверка текущей установки
    if check_docker; then
        print_warning "Docker уже установлен. Пропускаем установку."
        verify_installation
        show_post_install_info
        return 0
    fi
    
    # Подтверждение установки
    echo ""
    print_warning "Будет выполнена установка Docker на систему $DISTRO $VERSION"
    read -p "Продолжить установку? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Установка отменена"
        exit 0
    fi
    
    # Процесс установки
    check_old_docker
    update_system
    install_dependencies
    add_docker_gpg
    add_docker_repo
    install_docker_packages
    configure_docker_daemon
    start_docker_service
    add_user_to_docker_group
    install_docker_compose
    verify_installation
    create_aliases
    
    log "INFO" "Установка Docker завершена успешно"
    show_post_install_info
}

# Функция удаления Docker
uninstall_docker() {
    print_header
    print_warning "Эта операция удалит Docker и все связанные данные!"
    
    read -p "Вы уверены, что хотите удалить Docker? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Удаление отменено"
        exit 0
    fi
    
    print_info "Остановка Docker службы..."
    sudo systemctl stop docker || true
    sudo systemctl disable docker || true
    
    print_info "Удаление пакетов Docker..."
    sudo apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras
    
    print_info "Удаление конфигураций и данных..."
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/docker
    sudo rm -rf /etc/apt/sources.list.d/docker.list
    sudo rm -rf /etc/apt/keyrings/docker.gpg
    sudo rm -f /usr/local/bin/docker-compose
    sudo rm -f /usr/bin/docker-compose
    
    print_info "Очистка пакетов..."
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    # Удаление пользователя из группы docker
    print_info "Удаление пользователя из группы docker..."
    sudo gpasswd -d $USER docker || true
    
    print_success "Docker полностью удален из системы"
    log "INFO" "Docker удален из системы"
}

# Функция проверки системы
check_system() {
    print_header
    detect_distro
    check_architecture
    check_docker
}

# Функция помощи
show_help() {
    print_header
    echo -e "${CYAN}Использование: $0 [КОМАНДА]${NC}"
    echo ""
    echo "Команды:"
    echo "  install     - Установка Docker (по умолчанию)"
    echo "  uninstall   - Полное удаление Docker"
    echo "  check       - Проверка системы и установки Docker"
    echo "  help        - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  $0 install     # Установка Docker"
    echo "  $0 check       # Проверка системы"
    echo "  $0 uninstall   # Удаление Docker"
    echo ""
    echo -e "${YELLOW}Примечание: Не запускайте скрипт с sudo${NC}"
}

# Обработка аргументов
case "${1:-}" in
    "install")
        install_docker
        ;;
    "uninstall")
        uninstall_docker
        ;;
    "check")
        check_system
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        install_docker
        ;;
esac
