# ZRAM-SWAP-Optimizer
## ZRAM (SWAP) Optimizer Magisk Module
A lightweight Android script that enhances performance by:
* Automatic ZRAM Sizing:
Detects device RAM and sets ZRAM size dynamically:
-# 4GB RAM → 3GB ZRAM
-# 6GB RAM → 5GB ZRAM
-# 8GB RAM → 6GB ZRAM
-# 12GB RAM → 8GB ZRAM
* Optimizes compression (uses fast lz4 by default)
* Tunes VM settings for better memory management
* Auto-fallback to swap file if ZRAM fails
* Clean logging with device info (Log file can be found in /sdcard/zram_optimizer.log)

## Requirements
Your phone needs to be rooted in order to use this module.
Confirmed working on:
* Magisk
* Kitsune
* Apatch
* KSU

## How to install
1. Download the latest release
2. Open root manager (Magisk, Magisk Alpha, Kitsune, APatch or KernelSU)
3. Go to `Modules`
4. Tap `Install from storage`
5. Select the .zip file you just downloaded
6. Reboot device as required
