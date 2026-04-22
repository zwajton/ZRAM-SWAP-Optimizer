## Version 5
**Bug Fixes**
* Fixed log file accumulating across reboots — log is now wiped clean on every boot so each session starts fresh.
* Fixed compression algorithm being reset silently — it was applied before the ZRAM device reset, which wiped it. Now set correctly after each reset and before disksize is written.
* Fixed ZRAM fallback size not applying — inline env var assignment (`ZRAM_SIZE="2G" manage_zram`) doesn't update globals in POSIX sh. Split into a proper assignment and call.
* Fixed swappiness mismatch — config declared `SWAPPINESS=180` but the apply function hardcoded `100`. All VM settings now use their config variables.

**Improvements**
* All VM tuning values are now defined as named variables at the top of the script, making them easy to find and adjust.
* User override file: if `/sdcard/zram_config.sh` exists it is sourced at startup, allowing per-device tuning without editing the module.
* Fixed RAM detection fallback for devices with more than 12GB RAM — was incorrectly set to 4GB ZRAM (less than the 8GB given to 12GB devices), now correctly scales to 10GB.
* Removed the 5-minute background VM tuning loop — settings persist until something explicitly resets them and the loop was unnecessary overhead.
* Uninstall now immediately restores VM settings to Android defaults instead of leaving them active until the next reboot.

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
