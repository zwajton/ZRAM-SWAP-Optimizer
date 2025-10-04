#!/system/bin/sh

# =========================================
# Ultimate ZRAM Optimizer for Android
# =========================================

# Paths
LOG_FILE="/sdcard/zram_optimizer.log"
SWAPFILE="/data/swapfile"

# Settings
ZRAM_SIZE="6G"              # Target ZRAM size (falls back to 4G if needed)
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
    echo $SWAPPINESS > /proc/sys/vm/swappiness
    echo $WATERMARK_BOOST > /proc/sys/vm/watermark_boost_factor
    echo $WATERMARK_SCALE > /proc/sys/vm/watermark_scale_factor
    echo $PAGE_CLUSTER > /proc/sys/vm/page-cluster
    
    [ -f /sys/block/zram0/writeback ] && {
        echo 1 > /sys/block/zram0/writeback
        echo "50M" > /sys/block/zram0/writeback_limit
        log "Enabled ZRAM writeback (50MB limit)"
    }
    
    log "VM Settings:
    - swappiness=$SWAPPINESS
    - watermark_boost=$WATERMARK_BOOST
    - watermark_scale=$WATERMARK_SCALE
    - page-cluster=$PAGE_CLUSTER"
}

# --- Main Execution ---
main() {
    init_log  # Initialize log FIRST
    
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
            ZRAM_SIZE="4G" manage_zram && {
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