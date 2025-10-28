#!/bin/bash
# 🔧 Автоматическая установка Docker
# Автор: g1if

set -e

print_success() {
    echo -e "\033[0;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}

print_warning() {
    echo -e "\033[1;33m⚠️  $1\033[0m"
}

print_header() {
    echo -e "\033[0;36m"
    echo "🐳 ==========================================="
    echo "   АВТОМАТИЧЕСКАЯ УСТАНОВКА DOCKER"
    echo "   $(date)"
    echo "   Автор: g1if"
    echo "==========================================="
    echo -e "\033[0m"
}

check_docker() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

install_docker() {
    print_header
    
    # Проверяем, не установлен ли уже Docker
    if check_docker; then
        print_success "Docker уже установлен и работает"
        docker --version
        return 0
    fi
    
    echo "Начинаем установку Docker..."
    
    # Обновляем пакеты
    print_warning "Обновление списка пакетов..."
    sudo apt update
    
    # Устанавливаем зависимости
    print_warning "Установка зависимостей..."
    sudo apt install -y ca-certificates curl gnupg
    
    # Добавляем GPG ключ Docker
    print_warning "Добавление GPG ключа Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Добавляем репозиторий
    print_warning "Добавление репозитория Docker..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Обновляем пакеты с новым репозиторием
    sudo apt update
    
    # Устанавливаем Docker
    print_warning "Установка Docker..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Запускаем Docker
    print_warning "Запуск Docker демона..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Добавляем пользователя в группу docker
    print_warning "Добавление пользователя в группу docker..."
    sudo usermod -aG docker $USER
    
    print_success "Docker успешно установлен!"
    
    # Информация для пользователя
    echo ""
    print_warning "💡 ВАЖНО: Чтобы применить изменения группы, выполните:"
    echo "  newgrp docker"
    echo "  или перезайдите в систему"
    echo ""
    print_warning "📋 Проверка установки:"
    echo "  docker --version"
    echo "  docker ps"
}

# Проверяем права
if [ "$EUID" -eq 0 ]; then
    print_error "Не запускайте скрипт с sudo. Скрипт сам запросит права когда нужно."
    exit 1
fi

install_docker
EOF
