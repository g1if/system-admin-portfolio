#!/bin/bash

echo "🧪 ТЕСТИРОВАНИЕ ВСЕХ СКРИПТОВ СИСТЕМНОГО АДМИНИСТРАТОРА"
echo "====================================================="

# Создаем лог-файл
LOG_FILE="logs/script-tests.log"
mkdir -p logs
echo "Тестирование скриптов - $(date)" > $LOG_FILE

# Функция для тестирования скрипта
test_script() {
    local script_name=$1
    local test_command=$2
    
    echo -n "🔍 Тестируем $script_name... "
    
    if [ -f "./scripts/$script_name" ]; then
        if eval $test_command >> $LOG_FILE 2>&1; then
            echo "✅ OK"
            return 0
        else
            echo "❌ FAILED"
            return 1
        fi
    else
        echo "📛 NOT FOUND"
        return 2
    fi
}

# Тестируем скрипты
echo ""
echo "📋 ТЕСТИРУЕМ СКРИПТЫ:"
echo "===================="

test_script "system-monitor.sh" "./scripts/system-monitor.sh --help"
test_script "disk-manager.sh" "./scripts/disk-manager.sh info"
test_script "user-manager.sh" "./scripts/user-manager.sh --help"
test_script "service-manager.sh" "./scripts/service-manager.sh list"
test_script "network-analyzer.sh" "./scripts/network-analyzer.sh --help"
test_script "security-audit.sh" "./scripts/security-audit.sh --help"
test_script "backup-manager.sh" "./scripts/backup-manager.sh --help"
test_script "package-manager.sh" "./scripts/package-manager.sh help"
test_script "git-helper.sh" "./scripts/git-helper.sh --help"

# Проверяем права доступа
echo ""
echo "🔐 ПРОВЕРКА ПРАВ ДОСТУПА:"
echo "========================"

for script in ./scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "✅ $(basename $script): исполняемый"
        else
            echo "❌ $(basename $script): не исполняемый"
            chmod +x "$script"
            echo "   🔧 Исправлены права доступа"
        fi
    fi
done

echo ""
echo "📊 ИТОГИ ТЕСТИРОВАНИЯ:"
echo "====================="
echo "📝 Подробный лог: $LOG_FILE"
echo "💡 Совет: Проверь логи для детальной информации об ошибках"

# Проверяем наличие утилит
echo ""
echo "🛠️  ПРОВЕРКА ЗАВИСИМОСТЕЙ:"
echo "=========================="

check_dependency() {
    local dep=$1
    if command -v $dep &> /dev/null; then
        echo "✅ $dep: установлен"
    else
        echo "❌ $dep: не установлен"
    fi
}

check_dependency "smartctl"
check_dependency "iotop"
check_dependency "htop"
check_dependency "ncdu"
check_dependency "tree"
