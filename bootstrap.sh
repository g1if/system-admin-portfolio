#!/bin/bash
# 🚀 Универсальный установщик и настройщик системы
# Автор: g1if
# Версия: 1.0
# Репозиторий: https://github.com/g1if/system-admin-portfolio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/bootstrap.log"

# Создаем директории
mkdir -p "$LOG_DIR"

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
    echo -e "${BLUE}[$timestamp]${NC} [$level] $message"
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
    echo "🚀 ==========================================="
    echo "   АВТОМАТИЧЕСКАЯ УСТАНОВКА СИСТЕМЫ v1.0"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "${NC}"
}

# Проверка прав
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Этот скрипт требует прав root. Запустите с sudo."
        echo "Использование: sudo ./bootstrap.sh"
        exit 1
    fi
}

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
        PRETTY_NAME=$PRETTY_NAME
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
    
    print_info "Обнаружена система: $PRETTY_NAME"
}

# Проверка поддержки дистрибутива
check_distro_support() {
    case $DISTRO in
        ubuntu|debian)
            print_success "Дистрибутив $DISTRO поддерживается"
            ;;
        centos|rhel|fedora)
            print_warning "Дистрибутив $DISTRO поддерживается частично"
            ;;
        *)
            print_error "Дистрибутив $DISTRO не поддерживается"
            exit 1
            ;;
    esac
}

# Функции для разных дистрибутивов
update_system_ubuntu() {
    print_info "Обновление системы Ubuntu/Debian..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get clean
    
    print_success "Система обновлена"
}

update_system_centos() {
    print_info "Обновление системы CentOS/RHEL..."
    
    yum update -y
    yum autoremove -y
    yum clean all
    
    print_success "Система обновлена"
}

# Установка базовых пакетов
install_base_packages_ubuntu() {
    print_info "Установка базовых пакетов..."
    
    apt-get install -y \
        curl wget git vim nano htop \
        tree tmux zip unzip p7zip-full \
        net-tools dnsutils iputils-ping \
        software-properties-common \
        apt-transport-https ca-certificates \
        gnupg lsb-release \
        build-essential cmake make \
        python3 python3-pip python3-venv \
        jq yq bc apt-file \
        rsync rclone
    
    print_success "Базовые пакеты установлены"
}

install_base_packages_centos() {
    print_info "Установка базовых пакетов..."
    
    yum install -y \
        curl wget git vim nano htop \
        tree tmux zip unzip p7zip \
        net-tools bind-utils iputils \
        epel-release \
        python3 python3-pip \
        jq bc yum-utils \
        rsync rclone
    
    print_success "Базовые пакеты установлены"
}

# Установка инструментов мониторинга
install_monitoring_tools_ubuntu() {
    print_info "Установка инструментов мониторинга..."
    
    apt-get install -y \
        htop iotop iftop nethogs \
        nmon dstat sysstat \
        smartmontools \
        lm-sensors psensor \
        prometheus-node-exporter
    
    # Включение и запуск node-exporter
    systemctl enable node-exporter
    systemctl start node-exporter
    
    print_success "Инструменты мониторинга установлены"
}

# Установка инструментов безопасности
install_security_tools_ubuntu() {
    print_info "Установка инструментов безопасности..."
    
    apt-get install -y \
        fail2ban unattended-upgrades \
        logwatch aide rkhunter chkrootkit \
        ufw auditd acct \
        clamav clamav-daemon
    
    # Базовая настройка fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Настройка автоматических обновлений
    dpkg-reconfigure -plow unattended-upgrades
    
    print_success "Инструменты безопасности установлены"
}

# Установка Docker
install_docker() {
    print_info "Установка Docker..."
    
    if command -v docker &> /dev/null; then
        print_warning "Docker уже установлен"
        return 0
    fi
    
    # Используем скрипт из нашего портфолио
    if [ -f "$PROJECT_ROOT/scripts/install-docker.sh" ]; then
        sudo -u "$SUDO_USER" "$PROJECT_ROOT/scripts/install-docker.sh"
    else
        # Альтернативная установка
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Добавление пользователя в группу docker
        usermod -aG docker "$SUDO_USER"
    fi
    
    print_success "Docker установлен"
}

# Настройка базовой безопасности
setup_basic_security() {
    print_info "Настройка базовой безопасности..."
    
    # Настройка UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw --force enable
    
    # Настройка SSH
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Перезагрузка SSH
    systemctl restart sshd
    
    # Настройка парольной политики
    if [ -f /etc/login.defs ]; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs
    fi
    
    print_success "Базовая безопасность настроена"
}

# Настройка нашего портфолио скриптов
setup_portfolio_scripts() {
    print_info "Настройка скриптов портфолио..."
    
    # Даем права на выполнение
    chmod +x "$PROJECT_ROOT"/scripts/*.sh
    
    # Создаем симлинки в /usr/local/bin для удобства
    for script in "$PROJECT_ROOT"/scripts/*.sh; do
        local script_name=$(basename "$script" .sh)
        ln -sf "$script" "/usr/local/bin/$script_name" 2>/dev/null || true
    done
    
    # Создаем конфигурационные файлы
    sudo -u "$SUDO_USER" "$PROJECT_ROOT/scripts/system-monitor.sh" config
    sudo -u "$SUDO_USER" "$PROJECT_ROOT/scripts/alert-system.sh" config
    sudo -u "$SUDO_USER" "$PROJECT_ROOT/scripts/backup-manager.sh" config
    
    print_success "Скрипты портфолио настроены"
}

# Настройка cron задач
setup_cron_jobs() {
    print_info "Настройка автоматических задач..."
    
    local cron_file="/tmp/system-portfolio-cron"
    
    # Создаем временный cron файл
    cat > "$cron_file" << 'EOF'
# System Portfolio - Automated Tasks
# Обновление системы (еженедельно)
0 3 * * 1 root /usr/local/bin/package-manager.sh update

# Мониторинг системы (каждые 5 минут)
*/5 * * * * root /usr/local/bin/system-monitor.sh quick

# Резервное копирование (ежедневно в 2:00)
0 2 * * * root /usr/local/bin/backup-manager.sh create --auto

# Проверка безопасности (еженедельно)
0 4 * * 1 root /usr/local/bin/security-audit.sh quick

# Очистка логов (ежемесячно)
0 5 1 * * root /usr/local/bin/log-analyzer.sh clean

# Проверка SSL сертификатов (ежедневно)
0 6 * * * root /usr/local/bin/ssl-cert-checker.sh check
EOF

    # Добавляем в cron
    crontab "$cron_file"
    rm "$cron_file"
    
    print_success "Автоматические задачи настроены"
}

# Настройка мониторинга
setup_monitoring() {
    print_info "Настройка системы мониторинга..."
    
    # Создаем системd сервис для мониторинга
    local service_file="/etc/systemd/system/system-portfolio-monitor.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=System Portfolio Monitoring Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$PROJECT_ROOT/scripts/system-monitor.sh monitor
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable system-portfolio-monitor.service
    
    print_success "Система мониторинга настроена"
}

# Создание пользователя (опционально)
create_admin_user() {
    local username="${1:-}"
    
    if [ -z "$username" ]; then
        return 0
    fi
    
    print_info "Создание административного пользователя: $username"
    
    if id "$username" &>/dev/null; then
        print_warning "Пользователь $username уже существует"
        return 0
    fi
    
    # Создаем пользователя
    useradd -m -s /bin/bash "$username"
    usermod -aG sudo "$username"
    
    # Настраиваем SSH ключ
    local ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    
    print_success "Пользователь $username создан"
    print_warning "Не забудьте настроить SSH ключи для пользователя"
}

# Генерация отчета
generate_report() {
    print_info "Генерация отчета об установке..."
    
    local report_file="$LOG_DIR/bootstrap-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "ОТЧЕТ АВТОМАТИЧЕСКОЙ УСТАНОВКИ"
        echo "=============================="
        echo "Дата: $(date)"
        echo "Система: $PRETTY_NAME"
        echo "Пользователь: $SUDO_USER"
        echo ""
        echo "ВЫПОЛНЕННЫЕ ДЕЙСТВИЯ:"
        echo "-------------------"
        echo "✅ Обновление системы"
        echo "✅ Установка базовых пакетов"
        echo "✅ Установка инструментов мониторинга"
        echo "✅ Установка инструментов безопасности"
        echo "✅ Установка Docker"
        echo "✅ Настройка базовой безопасности"
        echo "✅ Настройка скриптов портфолио"
        echo "✅ Настройка автоматических задач"
        echo "✅ Настройка мониторинга"
        echo ""
        echo "ДОСТУПНЫЕ СКРИПТЫ:"
        echo "-----------------"
        ls "$PROJECT_ROOT/scripts"/*.sh | xargs -n1 basename | while read -r script; do
            echo "  🔧 $script"
        done
        echo ""
        echo "СЛЕДУЮЩИЕ ШАГИ:"
        echo "--------------"
        echo "1. Настройте SSH ключи для безопасного доступа"
        echo "2. Проверьте работу скриптов: $PROJECT_ROOT/scripts/test-all-scripts.sh"
        echo "3. Настройте оповещения: $PROJECT_ROOT/scripts/alert-system.sh config"
        echo "4. Настройте резервное копирование: $PROJECT_ROOT/scripts/backup-manager.sh config"
        echo ""
        echo "Логи установки: $LOG_FILE"
        
    } > "$report_file"
    
    print_success "Отчет сохранен: $report_file"
    cat "$report_file"
}

# Основная функция установки
main_installation() {
    print_header
    
    check_privileges
    detect_distro
    check_distro_support
    
    local username=""
    read -p "Создать административного пользователя? (оставьте пустым чтобы пропустить): " username
    
    print_info "Начинается установка системы. Это может занять несколько минут..."
    
    # Обновление системы
    case $DISTRO in
        ubuntu|debian) update_system_ubuntu ;;
        centos|rhel) update_system_centos ;;
    esac
    
    # Установка пакетов
    case $DISTRO in
        ubuntu|debian)
            install_base_packages_ubuntu
            install_monitoring_tools_ubuntu
            install_security_tools_ubuntu
            ;;
        centos|rhel)
            install_base_packages_centos
            ;;
    esac
    
    # Дополнительные настройки
    install_docker
    setup_basic_security
    setup_portfolio_scripts
    setup_cron_jobs
    setup_monitoring
    
    # Создание пользователя если указано
    if [ -n "$username" ]; then
        create_admin_user "$username"
    fi
    
    # Финальный отчет
    generate_report
    
    print_success "Установка завершена успешно!"
    print_warning "Рекомендуется перезагрузить систему: sudo reboot"
}

# Минимальная установка (только базовые пакеты)
minimal_installation() {
    print_header
    print_info "Минимальная установка..."
    
    check_privileges
    detect_distro
    
    case $DISTRO in
        ubuntu|debian)
            update_system_ubuntu
            install_base_packages_ubuntu
            ;;
        centos|rhel)
            update_system_centos
            install_base_packages_centos
            ;;
    esac
    
    setup_portfolio_scripts
    
    print_success "Минимальная установка завершена"
}

# Установка только Docker
docker_installation() {
    print_header
    print_info "Установка только Docker..."
    
    check_privileges
    install_docker
    setup_portfolio_scripts
    
    print_success "Установка Docker завершена"
}

# Показать справку
show_help() {
    print_header
    echo -e "${CYAN}Использование: $0 [КОМАНДА]${NC}"
    echo ""
    echo "Команды:"
    echo "  full       - Полная установка системы (по умолчанию)"
    echo "  minimal    - Минимальная установка (только базовые пакеты)"
    echo "  docker     - Установка только Docker"
    echo "  security   - Установка только инструментов безопасности"
    echo "  help       - Эта справка"
    echo ""
    echo "Примеры:"
    echo "  sudo $0 full        # Полная установка"
    echo "  sudo $0 minimal     # Минимальная установка"
    echo "  sudo $0 docker      # Только Docker"
    echo ""
    echo "Требования:"
    echo "  - Требуются права root"
    echo "  - Поддерживаемые системы: Ubuntu, Debian, CentOS, RHEL"
    echo ""
    echo "Логи: $LOG_FILE"
}

# Обработка аргументов
case "${1:-full}" in
    "full")
        main_installation
        ;;
    "minimal")
        minimal_installation
        ;;
    "docker")
        docker_installation
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
