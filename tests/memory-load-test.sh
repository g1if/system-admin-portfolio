#!/bin/bash
# Улучшенный тест нагрузки на память

echo "🧪 УЛУЧШЕННЫЙ ТЕСТ НАГРУЗКИ НА ПАМЯТЬ"
echo "===================================="

# Создаем несколько больших файлов в памяти
echo "Создаем нагрузку на память..."
echo "Этап 1: 500MB..."
dd if=/dev/zero of=/tmp/memory-test-1 bs=1M count=500 2>/dev/null &
sleep 2

echo "Этап 2: еще 500MB..."
dd if=/dev/zero of=/tmp/memory-test-2 bs=1M count=500 2>/dev/null &
sleep 2

echo "Этап 3: еще 500MB..."
dd if=/dev/zero of=/tmp/memory-test-3 bs=1M count=500 2>/dev/null &

echo ""
echo "✅ Нагрузка создана. Проверьте: ./scripts/alert-system.sh status"
echo ""
echo "💡 Для очистки выполните:"
echo "   rm -f /tmp/memory-test-* && killall dd"
