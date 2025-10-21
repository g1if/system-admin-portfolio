#!/bin/bash
# Умный системный монитор с автоопределением путей

# Автоопределение системных путей
SYSLOG_PATH=$(test -f /var/log/syslog && echo "/var/log/syslog" || echo "/var/log/messages")
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== System Monitor - $HOSTNAME ==="
echo "Timestamp: $TIMESTAMP"
echo ""

# Функция проверки доступности команд
check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# CPU usage с автоопределением метода
if check_command "mpstat"; then
    CPU_USAGE=$(mpstat 1 1 | awk '$3 ~ /[0-9.]+/ {print 100 - $3"%"}' | tail -1)
elif check_command "top"; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
else
    CPU_USAGE="N/A"
fi
echo "CPU Usage: $CPU_USAGE"

# Memory usage
if check_command "free"; then
    MEM_USAGE=$(free -h | grep Mem | awk '{print $3"/"$2 " ("$3/$2*100"%)"}')
else
    MEM_USAGE="N/A"
fi
echo "Memory: $MEM_USAGE"

# Disk space с определением корневого раздела
ROOT_DISK=$(df -h / | tail -1 | awk '{print $1}')
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
echo "Root Disk ($ROOT_DISK): $DISK_USAGE used"

# Active users
ACTIVE_USERS=$(who | wc -l)
echo "Active Users: $ACTIVE_USERS"

# System load
LOAD_AVG=$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}' || echo "N/A")
echo "Load Average: $LOAD_AVG"

# Uptime
UPTIME=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "N/A")
echo "Uptime: $UPTIME"
