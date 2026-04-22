#!/system/bin/sh

LOG_FILE="/sdcard/zram_optimizer.log"
LOG_ARCHIVE_DIR="/sdcard/zram_logs/"

restore_vm_defaults() {
    echo 60    > /proc/sys/vm/swappiness            2>/dev/null
    echo 3     > /proc/sys/vm/page-cluster          2>/dev/null
    echo 100   > /proc/sys/vm/vfs_cache_pressure    2>/dev/null
    echo 20    > /proc/sys/vm/dirty_ratio           2>/dev/null
    echo 10    > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 3000  > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
    echo 500   > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null
    echo 15000 > /proc/sys/vm/watermark_boost_factor 2>/dev/null
    echo 10    > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    echo "[UNINSTALL] VM settings restored to defaults"
}

cleanup() {
    [ -f "$LOG_FILE" ] && {
        rm -f "$LOG_FILE"
        echo "[UNINSTALL] Removed $LOG_FILE"
    }

    [ -d "$LOG_ARCHIVE_DIR" ] && {
        rm -rf "$LOG_ARCHIVE_DIR"
        echo "[UNINSTALL] Removed log archive directory"
    }

    [ -f "/data/swapfile" ] && {
        swapoff "/data/swapfile" 2>/dev/null
        rm -f "/data/swapfile"
        echo "[UNINSTALL] Removed swapfile"
    }
}

restore_vm_defaults
cleanup
exit 0
