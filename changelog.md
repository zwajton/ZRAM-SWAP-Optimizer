## Version 4
**Improvements**
Automatic ZRAM Sizing:
* Detects device RAM and sets ZRAM size dynamically:
  * 4GB RAM → 3GB ZRAM
  * 6GB RAM → 5GB ZRAM
  * 8GB RAM → 6GB ZRAM
  * 12GB RAM → 8GB ZRAM
* Live ZRAM Resize:
Attempts non-destructive ZRAM resizing before falling back to reset.
* Periodic VM Tuning:
Reapplies VM settings every 5 minutes to prevent system overrides.
* Detailed Logging:
Logs device model, kernel version, and memory stats before and after optimization.
**Bug Fixes**
* Ensures swapfile is cleaned up and recreated if needed.
* Handles missing or unsupported kernel features gracefully.

## Version 3
* Dynamically resizing ZRAM (6GB → falls back to 4GB if needed)
* Optimizes compression (uses fast lz4 by default)
* Tunes VM settings for better memory management
* Auto-fallback to swap file if ZRAM fails
* Clean logging with device info (Log file can be found in /sdcard/zram_optimizer.log)
