# ZRAM-SWAP-Optimizer
This module have been built mostly for phones used for gaming, especially for Pokémon Go.
It works on most devices, and can help with certain systems being aggresive when it comes to killing running apps due to memory.


## ZRAM (SWAP) Optimizer Magisk Module
A lightweight Android script that enhances performance by:
* Automatic ZRAM Sizing, Detects device RAM and sets ZRAM size dynamically. 
* Optimizes compression (uses fast lz4 by default)
* Tunes VM settings for better memory management
   * Periodic VM Tuning:
   * Reapplies VM settings every 5 minutes to prevent system overrides.
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
**Like always there is a risk of this module bootlooping the phone.**

### Credits

Thanks to VR-25 and his module <https://github.com/VR-25/zram-swap-manager> which gave me the idea to build this.
