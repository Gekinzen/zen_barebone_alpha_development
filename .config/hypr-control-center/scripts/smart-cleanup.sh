#!/bin/bash
# Smart Zombie Process Cleaner
# Only runs if zombies are detected

# Count zombie processes
ZOMBIE_COUNT=$(ps aux | awk '$8=="Z" {print $2}' | wc -l)

# Exit if no zombies
if [ "$ZOMBIE_COUNT" -eq 0 ]; then
    echo "No zombies found"
    exit 0
fi

echo "Found $ZOMBIE_COUNT zombie processes"

# Get zombie PIDs
ZOMBIE_PIDS=$(ps aux | awk '$8=="Z" {print $2}')

# Try to clean zombies by killing parent processes
for PID in $ZOMBIE_PIDS; do
    # Get parent PID
    PPID=$(ps -o ppid= -p $PID 2>/dev/null | tr -d ' ')
    
    if [ -n "$PPID" ] && [ "$PPID" != "1" ]; then
        # Don't kill init/systemd
        PNAME=$(ps -o comm= -p $PPID 2>/dev/null)
        
        # Skip critical processes
        if [[ "$PNAME" != "systemd" ]] && [[ "$PNAME" != "init" ]]; then
            echo "Cleaning zombie $PID (parent: $PPID - $PNAME)"
            kill -SIGCHLD $PPID 2>/dev/null
        fi
    fi
done

# Wait a moment
sleep 1

# Check if zombies were cleaned
NEW_ZOMBIE_COUNT=$(ps aux | awk '$8=="Z" {print $2}' | wc -l)

if [ "$NEW_ZOMBIE_COUNT" -lt "$ZOMBIE_COUNT" ]; then
    CLEANED=$((ZOMBIE_COUNT - NEW_ZOMBIE_COUNT))
    echo "Cleaned $CLEANED zombie processes"
else
    echo "Some zombies persist (system will clean on reboot)"
fi
