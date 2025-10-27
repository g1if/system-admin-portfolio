#!/bin/bash
# Тест нагрузки на память

echo "🧪 ТЕСТ НАГРУЗКИ НА ПАМЯТЬ"
echo "=========================="

# Создаем большой файл в памяти
echo "Создаем нагрузку на память..."
dd if=/dev/zero of=/tmp/memory-test bs=1M count=500 2>/dev/null &

echo "Нагрузка создана. Проверьте alert-system.sh status"
echo "Для очистки выполните: rm -f /tmp/memory-test && killall dd"
