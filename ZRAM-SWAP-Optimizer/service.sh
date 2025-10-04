#!/system/bin/sh

# =========================================
# Ultimate ZRAM Optimizer for Android
# =========================================

# Paths
LOG_FILE="/sdcard/zram_optimizer.log"
SWAPFILE="/data/swapfile"

# Settings
ZRAM_SIZE="4G"              # Target ZRAM size (falls back to 2G if needed)
COMP_ALGORITHM="lz4"        # Compression: lz4 (fast) | zstd (better compression)
MAX_RETRIES=2               # Reset attempts before fallback

# VM Tuning (Hardcoded as requested)
SWAPPINESS=180              # Aggressive swapping
WATERMARK_BOOST=0           # Disable watermark boosting
WATERMARK_SCALE=125         # More aggressive memory reclaim
PAGE_CLUSTER=0              # Disable readahead (better for flash)

# --- Logging Function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"  # Print to console
}

# --- Convert Human Size to Bytes ---
to_bytes() {
    echo "$1" | awk '
        /[0-9]$/{print $1}
        /K$/{print $1*1024}
        /M$/{print $1*1024*1024}
        /G$/{print $1*1024*1024*1024}'
}

# --- Detect RAM and Set ZRAM Size ---
set_zram_size_by_ram() {
    # Get total RAM in MB
    local total_ram_mb
    total_ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

    if [ "$total_ram_mb" -le 4096 ]; then
        ZRAM_SIZE="3G"
    elif [ "$total_ram_mb" -le 6144 ]; then
        ZRAM_SIZE="5G"
    elif [ "$total_ram_mb" -le 8192 ]; then
        ZRAM_SIZE="6G"
    elif [ "$total_ram_mb" -le 12288 ]; then
        ZRAM_SIZE="8G"
    else
        ZRAM_SIZE="4G"  # Fallback/default
    fi
    log "Detected RAM: ${total_ram_mb}MB, setting ZRAM_SIZE=$ZRAM_SIZE"
}

# --- ZRAM Management ---
manage_zram() {
    local target_size=$(to_bytes "$ZRAM_SIZE")
    local current_size=$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)
    
    # Skip if already at desired size
    [ "$current_size" -eq "$target_size" ] && {
        log "ZRAM already at $ZRAM_SIZE"
        return 0
    }

    # Attempt non-destructive resize first
    if [ "$current_size" -ne 0 ]; then
        log "Attempting live resize from $((current_size/1024/1024))M → $ZRAM_SIZE"
        echo "$target_size" > /sys/block/zram0/disksize 2>/dev/null
        sleep 1
        
        if [ $(cat /sys/block/zram0/disksize) -eq "$target_size" ]; then
            log "Live resize successful!"
            return 0
        fi
    fi

    # Full reset if needed
    for i in $(seq 1 $MAX_RETRIES); do
        log "Resetting ZRAM (attempt $i/$MAX_RETRIES)..."
        swapoff /dev/block/zram0 2>/dev/null
        sleep 1
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        sleep 2

        # Check if mm_stat was cleared
        if [ -f /sys/block/zram0/mm_stat ]; then
            mmstat=$(cat /sys/block/zram0/mm_stat | tr -d ' \t\n')
            if echo "$mmstat" | grep -vq '^0*$'; then
                log "⚠️  Warning: ZRAM mm_stat not fully cleared after reset: $(cat /sys/block/zram0/mm_stat)"
            fi
        fi

        echo "$target_size" > /sys/block/zram0/disksize 2>/dev/null
        [ $(cat /sys/block/zram0/disksize) -eq "$target_size" ] && break
    done

    # Verify final size
    if [ $(cat /sys/block/zram0/disksize) -eq "$target_size" ]; then
        log "ZRAM initialized at $ZRAM_SIZE"
        return 0
    else
        log "Failed to initialize ZRAM"
        return 1
    fi
}

# --- Swap File Fallback ---
setup_swapfile() {
    local size="2G"  # Conservative default
    
    [ -f "$SWAPFILE" ] && {
        swapoff "$SWAPFILE" 2>/dev/null
        rm "$SWAPFILE"
    }
    
    log "Creating swapfile ($size)..."
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$(( $(to_bytes "$size")/1024/1024 )) >> "$LOG_FILE" 2>&1
    
    mkswap "$SWAPFILE" >> "$LOG_FILE" 2>&1
    swapon "$SWAPFILE" >> "$LOG_FILE" 2>&1
    
    grep -q "$SWAPFILE" /proc/swaps && {
        log "Swapfile activated"
        return 0
    }
    return 1
}

# --- Compression Optimization ---
optimize_compression() {
    [ -f /sys/block/zram0/comp_algorithm ] || return
    
    if grep -q "$COMP_ALGORITHM" /sys/block/zram0/comp_algorithm; then
        echo "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm
        log "Set compression: $COMP_ALGORITHM"
    else
        log "Algorithm $COMP_ALGORITHM not available. Using default."
    fi
}

# --- VM Tuning ---
tune_vm() {
    # Read old values
    old_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    old_page_cluster=$(cat /proc/sys/vm/page-cluster 2>/dev/null)
    old_vfs_cache_pressure=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null)
    old_dirty_ratio=$(cat /proc/sys/vm/dirty_ratio 2>/dev/null)
    old_dirty_background_ratio=$(cat /proc/sys/vm/dirty_background_ratio 2>/dev/null)
    old_dirty_expire_centisecs=$(cat /proc/sys/vm/dirty_expire_centisecs 2>/dev/null)
    old_dirty_writeback_centisecs=$(cat /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null)
    old_watermark_boost=$(cat /proc/sys/vm/watermark_boost_factor 2>/dev/null)
    old_watermark_scale=$(cat /proc/sys/vm/watermark_scale_factor 2>/dev/null)

    # Apply new values
    echo 100 > /proc/sys/vm/swappiness
    echo 0 > /proc/sys/vm/page-cluster
    echo 10 > /proc/sys/vm/vfs_cache_pressure
    echo 80 > /proc/sys/vm/dirty_ratio
    echo 10 > /proc/sys/vm/dirty_background_ratio
    echo 6000 > /proc/sys/vm/dirty_expire_centisecs
    echo 6000 > /proc/sys/vm/dirty_writeback_centisecs
    echo 0 > /proc/sys/vm/watermark_boost_factor
    echo 125 > /proc/sys/vm/watermark_scale_factor
    
    [ -f /sys/block/zram0/writeback ] && {
        if echo 1 > /sys/block/zram0/writeback 2>/dev/null; then
        echo $((50 * 1024 * 1024)) > /sys/block/zram0/writeback_limit
        log "Enabled ZRAM writeback (50MB limit)"
        else
            log "ZRAM writeback not supported on this kernel."
        fi
    }
    
    log "VM Settings applied:
    - swappiness: $old_swappiness → 100
    - page-cluster: $old_page_cluster → 0
    - vfs_cache_pressure: $old_vfs_cache_pressure → 10
    - dirty_ratio: $old_dirty_ratio → 80
    - dirty_background_ratio: $old_dirty_background_ratio → 10
    - dirty_expire_centisecs: $old_dirty_expire_centisecs → 6000
    - dirty_writeback_centisecs: $old_dirty_writeback_centisecs → 6000
    - watermark_boost_factor: $old_watermark_boost → 0
    - watermark_scale_factor: $old_watermark_scale → 125"
}

# --- Main Execution ---
main() {
    sleep 15  # Delay before script runs
    # init_log  # Initialize log FIRST
    
    set_zram_size_by_ram # Optional: set ZRAM size based on RAM (if implemented)

    # Wait for system (with logging)
    log "Waiting for system boot..."
    while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        sleep 2
    done
    sleep 5
    log "System ready"

    # Initialize log file
	{
        echo "# ========================================="
        echo "# $(date '+%Y-%m-%d %H:%M:%S') - NEW SESSION"
        echo "# Ultimate ZRAM Optimizer for Android"
        echo "# Device: $(getprop ro.product.model || echo 'unknown')"
        echo "# Kernel: $(uname -r || echo 'unknown')"
        echo "# ========================================="
        echo ""
    } > "$LOG_FILE"
	
    log "Pre-optimization memory:"
    free -m >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # ZRAM handling
    if [ -e /sys/block/zram0/disksize ]; then
        optimize_compression
        if manage_zram; then
            mkswap /dev/block/zram0 >> "$LOG_FILE" 2>&1
            swapon /dev/block/zram0 >> "$LOG_FILE" 2>&1
        else
            log "Falling back to smaller size..."
            ZRAM_SIZE="2G" manage_zram && {
                mkswap /dev/block/zram0 >> "$LOG_FILE" 2>&1
                swapon /dev/block/zram0 >> "$LOG_FILE" 2>&1
            } || setup_swapfile
        fi
    else
        log "ZRAM not supported. Using swapfile."
        setup_swapfile
    fi
    
    # Apply VM tuning
    tune_vm

    # Reapply VM tuning every 5 minutes in the background
    (
        while true; do
            sleep 300
            tune_vm
        done
    ) &
    
    # Results
    log "=== Final Status ==="
    log "Active swap:"
    cat /proc/swaps >> "$LOG_FILE"
    log "Memory status:"
    free -m >> "$LOG_FILE"
    log "ZRAM stats:"
    cat /sys/block/zram0/mm_stat 2>/dev/null >> "$LOG_FILE" || log "N/A"
    log "Operation complete."
}

# Execute
main
