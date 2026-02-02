#!/bin/bash
# ============================================================
# Power Cleanup Script for Hyprland Control Center
# Smart zombie detection + RAM/cache cleanup
# ============================================================
# Usage: ./power-cleanup.sh [quick|deep]
#   quick - Clean zombies + drop page cache (default)
#   deep  - Quick + clear swap + compact memory
# ============================================================

set -o pipefail

MODE="${1:-quick}"
CLEANED_ZOMBIES=0
FREED_MB=0
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }

# ============================================================
# Zombie Process Detection & Cleanup
# ============================================================
cleanup_zombies() {
    log_info "Scanning for zombie processes..."
    
    # Method 1: ps with stat column (most reliable)
    # Zombie state shows as 'Z' or 'Z+' or 'Zs' etc.
    mapfile -t ZOMBIE_PIDS < <(ps -eo pid,stat,ppid,comm --no-headers | awk '$2 ~ /^Z/ {print $1}')
    
    ZOMBIE_COUNT=${#ZOMBIE_PIDS[@]}
    
    if [ "$ZOMBIE_COUNT" -eq 0 ]; then
        log_ok "No zombie processes found"
        return 0
    fi
    
    log_warn "Found $ZOMBIE_COUNT zombie process(es)"
    
    # List zombies with details
    echo ""
    echo "  PID    PPID   Parent Process"
    echo "  -----  -----  --------------"
    
    for PID in "${ZOMBIE_PIDS[@]}"; do
        [ -z "$PID" ] && continue
        
        # Get parent info
        PPID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
        PARENT_NAME=$(ps -o comm= -p "$PPID" 2>/dev/null)
        
        printf "  %-5s  %-5s  %s\n" "$PID" "$PPID" "$PARENT_NAME"
    done
    echo ""
    
    # Attempt cleanup
    log_info "Attempting to reap zombie processes..."
    
    for PID in "${ZOMBIE_PIDS[@]}"; do
        [ -z "$PID" ] && continue
        
        PPID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
        
        # Skip if parent is init/systemd (PID 1) or kernel thread (PID 2)
        if [ -z "$PPID" ] || [ "$PPID" -le 2 ]; then
            log_warn "Zombie $PID: parent is system process, skipping"
            continue
        fi
        
        PARENT_NAME=$(ps -o comm= -p "$PPID" 2>/dev/null)
        
        # Skip critical system processes
        case "$PARENT_NAME" in
            systemd|init|kthreadd|rcu_*|watchdog*|migration*|ksoftirqd*|kworker*)
                log_warn "Zombie $PID: parent '$PARENT_NAME' is critical, skipping"
                continue
                ;;
        esac
        
        # Send SIGCHLD to parent to trigger wait() call
        if kill -SIGCHLD "$PPID" 2>/dev/null; then
            log_info "Sent SIGCHLD to $PPID ($PARENT_NAME)"
            ((CLEANED_ZOMBIES++))
        else
            log_warn "Failed to signal parent $PPID"
        fi
    done
    
    # Brief pause for parent processes to reap
    sleep 0.5
    
    # Recount zombies
    NEW_COUNT=$(ps -eo stat --no-headers | grep -c '^Z' 2>/dev/null || echo 0)
    
    if [ "$NEW_COUNT" -lt "$ZOMBIE_COUNT" ]; then
        REAPED=$((ZOMBIE_COUNT - NEW_COUNT))
        log_ok "Successfully reaped $REAPED zombie process(es)"
    elif [ "$NEW_COUNT" -eq 0 ]; then
        log_ok "All zombie processes cleaned"
    else
        log_warn "$NEW_COUNT zombie(s) still remain (will be cleaned on reboot)"
    fi
}

# ============================================================
# Page Cache Cleanup
# ============================================================
cleanup_caches() {
    log_info "Cleaning page cache and dentries..."
    
    # Get current cache size (Cached + Buffers in KB)
    CACHE_BEFORE=$(awk '/^(Cached|Buffers):/ {sum += $2} END {print sum}' /proc/meminfo)
    CACHE_BEFORE_MB=$((CACHE_BEFORE / 1024))
    
    log_info "Current cache size: ${CACHE_BEFORE_MB}MB"
    
    # Sync filesystem buffers first
    sync
    
    # Drop caches
    # 1 = page cache only
    # 2 = dentries and inodes
    # 3 = page cache + dentries + inodes
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    else
        # Need elevated privileges
        if sudo -n true 2>/dev/null; then
            sudo -n sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null
        elif command -v pkexec &>/dev/null; then
            pkexec sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null
        else
            log_warn "Cannot drop caches: need root privileges"
            log_info "Run with: sudo $0"
            return 1
        fi
    fi
    
    # Measure freed memory
    sleep 0.3
    CACHE_AFTER=$(awk '/^(Cached|Buffers):/ {sum += $2} END {print sum}' /proc/meminfo)
    CACHE_AFTER_MB=$((CACHE_AFTER / 1024))
    
    FREED_KB=$((CACHE_BEFORE - CACHE_AFTER))
    FREED_MB=$((FREED_KB / 1024))
    
    if [ "$FREED_MB" -gt 0 ]; then
        log_ok "Freed ${FREED_MB}MB from cache"
    else
        log_ok "Cache already optimized"
    fi
}

# ============================================================
# Swap Cleanup (Deep mode only)
# ============================================================
cleanup_swap() {
    log_info "Checking swap usage..."
    
    # Get swap info in MB
    read -r SWAP_TOTAL SWAP_USED SWAP_FREE <<< $(free -m | awk '/^Swap:/ {print $2, $3, $4}')
    
    if [ "$SWAP_TOTAL" -eq 0 ]; then
        log_info "No swap configured"
        return 0
    fi
    
    if [ "$SWAP_USED" -eq 0 ]; then
        log_ok "Swap is empty"
        return 0
    fi
    
    log_info "Swap usage: ${SWAP_USED}MB / ${SWAP_TOTAL}MB"
    
    # Check if we have enough free RAM
    FREE_RAM=$(free -m | awk '/^Mem:/ {print $7}')
    
    if [ "$FREE_RAM" -lt "$SWAP_USED" ]; then
        log_warn "Not enough free RAM (${FREE_RAM}MB) to safely clear swap (${SWAP_USED}MB)"
        log_warn "Skipping swap cleanup to avoid OOM"
        return 1
    fi
    
    log_info "Clearing swap (moving ${SWAP_USED}MB to RAM)..."
    
    # Disable and re-enable swap
    if sudo -n true 2>/dev/null; then
        if sudo -n swapoff -a 2>/dev/null; then
            sudo -n swapon -a 2>/dev/null
            log_ok "Swap cleared: ${SWAP_USED}MB freed"
            FREED_MB=$((FREED_MB + SWAP_USED))
        else
            log_error "Failed to disable swap"
            return 1
        fi
    else
        log_warn "Cannot clear swap: need root privileges"
        return 1
    fi
}

# ============================================================
# Memory Compaction (Deep mode only)
# ============================================================
compact_memory() {
    log_info "Compacting memory..."
    
    if [ ! -f /proc/sys/vm/compact_memory ]; then
        log_warn "Memory compaction not supported on this kernel"
        return 1
    fi
    
    if sudo -n true 2>/dev/null; then
        sudo -n sh -c 'echo 1 > /proc/sys/vm/compact_memory' 2>/dev/null
        log_ok "Memory compaction triggered"
    else
        log_warn "Cannot compact memory: need root privileges"
        return 1
    fi
}

# ============================================================
# System Summary
# ============================================================
show_summary() {
    echo ""
    echo "=========================================="
    echo "  Cleanup Summary"
    echo "=========================================="
    
    # Current memory state
    read -r MEM_TOTAL MEM_USED MEM_FREE MEM_AVAILABLE <<< $(free -m | awk '/^Mem:/ {print $2, $3, $4, $7}')
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
    
    echo "  Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)"
    echo "  Available: ${MEM_AVAILABLE}MB"
    
    # Swap state
    read -r SWAP_TOTAL SWAP_USED <<< $(free -m | awk '/^Swap:/ {print $2, $3}')
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
        echo "  Swap: ${SWAP_USED}MB / ${SWAP_TOTAL}MB (${SWAP_PERCENT}%)"
    fi
    
    # Zombie count
    ZOMBIE_NOW=$(ps -eo stat --no-headers | grep -c '^Z' 2>/dev/null || echo 0)
    echo "  Zombies: $ZOMBIE_NOW"
    
    echo ""
    echo "  Freed: ~${FREED_MB}MB"
    echo "  Zombies handled: $CLEANED_ZOMBIES"
    echo "  Errors: $ERRORS"
    echo "=========================================="
}

# ============================================================
# Main Execution
# ============================================================
main() {
    echo ""
    echo "Power Cleanup Script v1.0"
    echo "Mode: $MODE"
    echo ""
    
    # Run cleanup based on mode
    cleanup_zombies
    echo ""
    
    cleanup_caches
    echo ""
    
    if [ "$MODE" = "deep" ]; then
        cleanup_swap
        echo ""
        
        compact_memory
        echo ""
    fi
    
    show_summary
    
    # Return status
    if [ "$ERRORS" -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main
main "$@"