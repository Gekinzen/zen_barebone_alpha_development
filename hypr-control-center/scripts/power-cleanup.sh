#!/bin/bash
MODE="${1:-quick}"
CLEANED=0
FREED_MB=0

cleanup_zombies() {
    ZOMBIE_PIDS=$(ps -eo pid,stat | awk '$2 ~ /^Z/ {print $1}')
    ZOMBIE_COUNT=$(echo "$ZOMBIE_PIDS" | grep -c '[0-9]' 2>/dev/null || echo 0)
    
    if [ "$ZOMBIE_COUNT" -eq 0 ] || [ -z "$ZOMBIE_PIDS" ]; then
        return 0
    fi
    
    for PID in $ZOMBIE_PIDS; do
        [ -z "$PID" ] && continue
        PPID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
        
        if [ -n "$PPID" ] && [ "$PPID" != "1" ] && [ "$PPID" != "0" ]; then
            PNAME=$(ps -o comm= -p "$PPID" 2>/dev/null)
            case "$PNAME" in
                systemd|init|kthreadd|rcu*|watchdog*) continue ;;
            esac
            kill -SIGCHLD "$PPID" 2>/dev/null
            ((CLEANED++))
        fi
    done
}

cleanup_caches() {
    CACHE_BEFORE=$(grep -E "^(Cached|Buffers):" /proc/meminfo | awk '{sum += $2} END {print sum}')
    sync
    sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null
    CACHE_AFTER=$(grep -E "^(Cached|Buffers):" /proc/meminfo | awk '{sum += $2} END {print sum}')
    
    if [ -n "$CACHE_BEFORE" ] && [ -n "$CACHE_AFTER" ]; then
        FREED_KB=$((CACHE_BEFORE - CACHE_AFTER))
        [ "$FREED_KB" -gt 0 ] && FREED_MB=$((FREED_KB / 1024))
    fi
}

cleanup_swap() {
    SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')
    [ "$SWAP_USED" -eq 0 ] && return 0
    
    FREE_RAM=$(free -m | awk '/^Mem:/ {print $7}')
    if [ "$FREE_RAM" -gt "$SWAP_USED" ]; then
        sudo -n swapoff -a 2>/dev/null && sudo -n swapon -a 2>/dev/null
    fi
}

compact_memory() {
    [ -f /proc/sys/vm/compact_memory ] &&         sudo -n sh -c 'echo 1 > /proc/sys/vm/compact_memory' 2>/dev/null
}

cleanup_zombies
cleanup_caches

if [ "$MODE" = "deep" ]; then
    cleanup_swap
    compact_memory
fi

echo "Cleanup complete: $CLEANED zombies handled, ~${FREED_MB}MB freed"
