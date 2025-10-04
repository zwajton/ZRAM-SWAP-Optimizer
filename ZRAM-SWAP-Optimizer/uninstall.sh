#!/system/bin/sh

LOG_FILE="/sdcard/zram_optimizer.log"
LOG_ARCHIVE_DIR="/sdcard/zram_logs/"

cleanup() {
    # Remove main log
    [ -f "$LOG_FILE" ] && {
        rm -f "$LOG_FILE"
        echo "[UNINSTALL] Removed $LOG_FILE"
    }
    
    # Remove archived logs
    [ -d "$LOG_ARCHIVE_DIR" ] && {
        rm -rf "$LOG_ARCHIVE_DIR"
        echo "[UNINSTALL] Removed log archive directory"
    }
    
    # Additional cleanup for swapfile if created by module
    [ -f "/data/swapfile" ] && {
        swapoff "/data/swapfile" 2>/dev/null
        rm -f "/data/swapfile"
        echo "[UNINSTALL] Removed swapfile"
    }
}

cleanup
exit 0