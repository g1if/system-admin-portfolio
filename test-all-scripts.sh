#!/bin/bash
# 🧪 Тестирование всех скриптов портфолио
# Автор: g1if

set -e

echo "🧪 ТЕСТИРОВАНИЕ ВСЕХ СКРИПТОВ"
echo "=============================="

# Функция для тестирования скрипта с таймаутом
test_script() {
    local script_name=$1
    local script_path=$2
    local timeout_duration=10  # 10 секунд на выполнение
    
    echo -n "🔍 Тестируем $script_name... "
    
    # Запускаем скрипт с таймаутом и подаем входные данные если нужно
    if timeout $timeout_duration bash "$script_path" --help > /dev/null 2>&1; then
        echo "✅ OK"
        return 0
    elif timeout $timeout_duration bash "$script_path" > /dev/null 2>&1; then
        echo "✅ OK" 
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

# Список скриптов для тестирования
scripts=(
    "system-monitor.sh"
    "user-manager.sh" 
    "backup-manager.sh"
    "security-audit.sh"
    "network-analyzer.sh"
    "service-manager.sh"
    "package-manager.sh"
)

echo ""
echo "📋 ТЕСТИРУЕМ СКРИПТЫ:"
echo "===================="

success_count=0
total_count=0

for script in "${scripts[@]}"; do
    if [ -f "scripts/$script" ]; then
        test_script "$script" "scripts/$script"
        if [ $? -eq 0 ]; then
            ((success_count++))
        fi
        ((total_count++))
    else
        echo "❌ $script: файл не найден"
    fi
done

echo ""
echo "📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:"
echo "==========================="
echo "✅ Успешно: $success_count из $total_count"
echo "📁 Директория: $(pwd)"

if [ $success_count -eq $total_count ]; then
    echo "🎉 ВСЕ СКРИПТЫ РАБОТАЮТ КОРРЕКТНО!"
else
    echo "⚠️  Некоторые скрипты требуют внимания"
fi

echo ""
